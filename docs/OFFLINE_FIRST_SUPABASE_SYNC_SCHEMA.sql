-- OFFLINE-FIRST POS SYNC (Supabase PostgreSQL) — Reference Schema
-- Date: 2026-02-22
--
-- DO NOT RUN THIS FILE AS A MIGRATION.
-- Use docs/SUPABASE_OFFLINE_FIRST_MIGRATION_14_RULES.sql for a run-ready example.
--
-- This file is a DESIGN REFERENCE to implement the offline-first rules:
-- 1) UUID keys, 2) Soft delete, 3) Snapshotting, 4) Queue/Idempotency,
-- 5) Conflict-safe writes, 6) Tenant isolation, 7) Auditing,
-- 8) Schema versioning & migration gate, 9) Cursor-based delta sync,
-- 10) Media/storage separation, 11) Negative inventory logging,
-- 12) Background sync strategy (client-side),
-- 13) Local data purging (client-side),
-- 14) Token refresh (client-side; see docs/SYNC_MANAGER_PSEUDOCODE.md).
--
-- Notes:
-- - Keep money in NUMERIC with fixed scale.
-- - Do NOT block sales on negative stock; log as CONFLICT_WARNING.
-- - Prefer Edge Functions for sync orchestration; SQL here provides the tables + triggers.
--
-- This is not meant to be executed blindly against production.

-- ─────────────────────────────────────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8) Schema Versioning & Migration (server-side gate)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.app_schema_state (
  id int primary key default 1 check (id = 1),
  current_version int not null,
  min_supported_version int not null,
  force_update_below_min boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_schema_migrations (
  from_version int not null,
  to_version int not null,
  -- Can be SQL, JSON "migration plan", or a pointer to a bundled migration id.
  migration_script text not null,
  sha256 text,
  created_at timestamptz not null default now(),
  primary key (from_version, to_version)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Multi-tenant core (rule 6)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.devices (
  -- Client-generated UUID (stable per install)
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  hardware_id text,
  platform text,
  app_version text,
  schema_version int not null,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists devices_tenant_last_seen_idx
  on public.devices (tenant_id, last_seen_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) Queue / Idempotency receipts (server-side)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.sync_op_receipts (
  -- Client operation id (UUID) — guarantees idempotency (exactly-once effect)
  op_id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  client_seq bigint not null,
  table_name text not null,
  action text not null check (action in ('upsert', 'delete')),
  row_id uuid not null,
  applied_at timestamptz not null default now(),
  -- Optional: store application result / server row_version etc.
  result jsonb not null default '{}'::jsonb
);
create unique index if not exists sync_op_receipts_device_seq_uniq
  on public.sync_op_receipts (device_id, client_seq);

create table if not exists public.sync_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  schema_version int not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running', 'ok', 'error')),
  stats jsonb not null default '{}'::jsonb
);
create index if not exists sync_sessions_tenant_started_idx
  on public.sync_sessions (tenant_id, started_at desc);

-- Optional: server-side copy of cursors for observability (client is source of truth).
create table if not exists public.sync_cursors (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  table_name text not null,
  last_pulled_at timestamptz not null default 'epoch'::timestamptz,
  last_pulled_id uuid,
  updated_at timestamptz not null default now(),
  primary key (device_id, table_name)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) Snapshotting / Auditing
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.row_snapshots (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  table_name text not null,
  row_id uuid not null,
  op_id uuid,
  device_id uuid references public.devices(id) on delete set null,
  -- Store BEFORE and/or AFTER; use what you need for audit/rollback.
  before_snapshot jsonb,
  after_snapshot jsonb,
  reason text,
  created_at timestamptz not null default now()
);
create index if not exists row_snapshots_lookup_idx
  on public.row_snapshots (tenant_id, table_name, row_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10) Media / Storage Separation
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.media_objects (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  bucket text not null default 'media',
  object_path text not null,
  public_url text,
  mime_type text,
  size_bytes bigint,
  sha256 text,
  status text not null default 'uploaded' check (status in ('pending', 'uploaded', 'failed')),
  device_id uuid references public.devices(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists media_objects_bucket_path_uniq
  on public.media_objects (bucket, object_path);

-- ─────────────────────────────────────────────────────────────────────────────
-- 11) Negative Inventory Logging (+ admin notification)
-- ─────────────────────────────────────────────────────────────────────────────
create type if not exists public.inventory_log_tag as enum ('NORMAL', 'CONFLICT_WARNING');

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  type text not null,
  severity text not null default 'info' check (severity in ('info', 'warning', 'critical')),
  title text not null,
  body text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists admin_notifications_tenant_created_idx
  on public.admin_notifications (tenant_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- Common columns & trigger helpers (rules 1,2,9)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.trg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- On soft-delete updates, keep updated_at moving so cursor-based sync sees tombstones.
create or replace function public.trg_soft_delete_bump_updated_at()
returns trigger
language plpgsql
as $$
begin
  if (old.deleted_at is distinct from new.deleted_at) then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Example business tables (POS core) — pattern to apply across all tables
-- Each table:
-- - id uuid PK (client generates)
-- - tenant_id uuid (RLS scope)
-- - created_at/updated_at
-- - deleted_at for soft delete
-- - index(tenant_id, updated_at, id) for cursor-based delta sync
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.products (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  sku text,
  name text not null,
  image_url text, -- from Supabase Storage (NOT base64 in queue)
  price numeric(18,2) not null default 0,
  currency text not null default 'TRY',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists products_delta_idx
  on public.products (tenant_id, updated_at, id);
create trigger trg_products_updated_at
  before update on public.products
  for each row execute function public.trg_set_updated_at();
create trigger trg_products_soft_delete_bump
  before update on public.products
  for each row execute function public.trg_soft_delete_bump_updated_at();

create table if not exists public.warehouses (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists warehouses_delta_idx
  on public.warehouses (tenant_id, updated_at, id);
create trigger trg_warehouses_updated_at
  before update on public.warehouses
  for each row execute function public.trg_set_updated_at();
create trigger trg_warehouses_soft_delete_bump
  before update on public.warehouses
  for each row execute function public.trg_soft_delete_bump_updated_at();

-- Immutable-ish financial events: prefer append-only, avoid UPDATE conflicts.
create table if not exists public.sales (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  sale_no text,
  status text not null default 'completed' check (status in ('completed', 'voided', 'refunded')),
  currency text not null default 'TRY',
  total_amount numeric(18,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists sales_delta_idx
  on public.sales (tenant_id, updated_at, id);
create trigger trg_sales_updated_at
  before update on public.sales
  for each row execute function public.trg_set_updated_at();
create trigger trg_sales_soft_delete_bump
  before update on public.sales
  for each row execute function public.trg_soft_delete_bump_updated_at();

create table if not exists public.sale_items (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  warehouse_id uuid references public.warehouses(id) on delete restrict,
  qty numeric(18,3) not null,
  unit_price numeric(18,2) not null,
  line_total numeric(18,2) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists sale_items_delta_idx
  on public.sale_items (tenant_id, updated_at, id);
create trigger trg_sale_items_updated_at
  before update on public.sale_items
  for each row execute function public.trg_set_updated_at();
create trigger trg_sale_items_soft_delete_bump
  before update on public.sale_items
  for each row execute function public.trg_soft_delete_bump_updated_at();

create table if not exists public.payments (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  method text not null,
  amount numeric(18,2) not null,
  currency text not null default 'TRY',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists payments_delta_idx
  on public.payments (tenant_id, updated_at, id);
create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.trg_set_updated_at();
create trigger trg_payments_soft_delete_bump
  before update on public.payments
  for each row execute function public.trg_soft_delete_bump_updated_at();

-- Inventory: balance table is a fast materialization (can be rebuilt from movements).
create table if not exists public.inventory_balances (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty numeric(18,3) not null default 0,
  updated_at timestamptz not null default now(),
  primary key (warehouse_id, product_id)
);

create table if not exists public.inventory_movements (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  -- Optional: link to operation receipt for auditing
  op_id uuid,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  qty_change numeric(18,3) not null,
  reason text not null,
  source_table text,
  source_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists inventory_movements_delta_idx
  on public.inventory_movements (tenant_id, updated_at, id);
create unique index if not exists inventory_movements_source_uniq
  on public.inventory_movements (tenant_id, source_table, source_id)
  where source_table is not null and source_id is not null;
create trigger trg_inventory_movements_updated_at
  before update on public.inventory_movements
  for each row execute function public.trg_set_updated_at();
create trigger trg_inventory_movements_soft_delete_bump
  before update on public.inventory_movements
  for each row execute function public.trg_soft_delete_bump_updated_at();

create table if not exists public.inventory_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  product_id uuid not null references public.products(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  movement_id uuid references public.inventory_movements(id) on delete set null,
  tag public.inventory_log_tag not null default 'NORMAL',
  qty_before numeric(18,3),
  qty_change numeric(18,3) not null,
  qty_after numeric(18,3),
  message text,
  created_at timestamptz not null default now()
);
create index if not exists inventory_logs_tenant_created_idx
  on public.inventory_logs (tenant_id, created_at desc);

-- Apply movement to balances + log negative inventory as CONFLICT_WARNING.
create or replace function public.trg_apply_inventory_movement()
returns trigger
language plpgsql
as $$
declare
  v_before numeric(18,3);
  v_after numeric(18,3);
  v_tag public.inventory_log_tag := 'NORMAL';
begin
  if (tg_op = 'DELETE') then
    return old;
  end if;

  -- Ignore soft deleted movements
  if (new.deleted_at is not null) then
    return new;
  end if;

  -- Lock and read current balance
  select b.qty
    into v_before
  from public.inventory_balances b
  where b.warehouse_id = new.warehouse_id
    and b.product_id = new.product_id
  for update;

  if v_before is null then
    v_before := 0;
  end if;

  v_after := v_before + new.qty_change;

  insert into public.inventory_balances (tenant_id, warehouse_id, product_id, qty, updated_at)
  values (new.tenant_id, new.warehouse_id, new.product_id, v_after, now())
  on conflict (warehouse_id, product_id) do update
    set qty = excluded.qty,
        updated_at = excluded.updated_at;

  if v_after < 0 then
    v_tag := 'CONFLICT_WARNING';
  end if;

  insert into public.inventory_logs (
    tenant_id, device_id, product_id, warehouse_id, movement_id,
    tag, qty_before, qty_change, qty_after, message
  )
  values (
    new.tenant_id, new.device_id, new.product_id, new.warehouse_id, new.id,
    v_tag, v_before, new.qty_change, v_after,
    case when v_tag = 'CONFLICT_WARNING'
      then 'Negative stock detected. Sale not blocked; logged for admin review.'
      else null end
  );

  if v_tag = 'CONFLICT_WARNING' then
    insert into public.admin_notifications (
      tenant_id, type, severity, title, body, metadata
    )
    values (
      new.tenant_id,
      'inventory_negative',
      'warning',
      'Negative Inventory Warning',
      'Stock went negative due to concurrent/offline sales. Review inventory logs.',
      jsonb_build_object(
        'product_id', new.product_id,
        'warehouse_id', new.warehouse_id,
        'movement_id', new.id,
        'qty_before', v_before,
        'qty_change', new.qty_change,
        'qty_after', v_after
      )
    );
  end if;

  return new;
end;
$$;

create trigger trg_apply_inventory_movement
  after insert on public.inventory_movements
  for each row execute function public.trg_apply_inventory_movement();

-- Optional convenience: when a sale item is inserted, create a movement row.
-- This keeps sales "kutsal" and turns inventory into derived state.
create or replace function public.trg_sale_item_create_inventory_movement()
returns trigger
language plpgsql
as $$
begin
  if (tg_op = 'DELETE') then
    return old;
  end if;

  if (new.deleted_at is not null) then
    return new;
  end if;

  -- Decrease stock for sales
  insert into public.inventory_movements (
    id,
    tenant_id,
    device_id,
    warehouse_id,
    product_id,
    qty_change,
    reason,
    source_table,
    source_id
  )
  values (
    gen_random_uuid(),
    new.tenant_id,
    null,
    coalesce(new.warehouse_id, (select id from public.warehouses w where w.tenant_id = new.tenant_id limit 1)),
    new.product_id,
    -abs(new.qty),
    'sale',
    'sale_items',
    new.id
  )
  on conflict (tenant_id, source_table, source_id) do nothing;

  return new;
end;
$$;

create trigger trg_sale_item_create_inventory_movement
  after insert on public.sale_items
  for each row execute function public.trg_sale_item_create_inventory_movement();

-- ─────────────────────────────────────────────────────────────────────────────
-- 9) Cursor-Based Delta Sync (pattern)
-- ─────────────────────────────────────────────────────────────────────────────
-- Client keeps per-table cursor:
--   cursor = (last_pulled_at, last_pulled_id)
-- Pull query shape (per table):
--
--   select *
--   from <table>
--   where tenant_id = $tenant
--     and (
--       updated_at > $last_pulled_at
--       or (updated_at = $last_pulled_at and id > $last_pulled_id)
--     )
--   order by updated_at asc, id asc
--   limit $limit;
--
-- Always include soft-delete tombstones (deleted_at is not null) in the same stream
-- because updated_at moves when deleted_at changes (trigger above).
