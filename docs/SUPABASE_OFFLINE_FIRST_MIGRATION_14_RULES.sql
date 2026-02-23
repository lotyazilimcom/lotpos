-- SUPABASE OFFLINE-FIRST POS MIGRATION (14 ALTIN KURAL) — RUN-READY EXAMPLE
-- Date: 2026-02-22
--
-- Purpose
-- - This script creates a minimal, end-to-end example schema for an Offline-First POS sync engine.
-- - It is designed for Supabase PostgreSQL and intended to be executed (once) in a DEV/TEST project first.
--
-- What this script includes
-- - UUID v4 primary keys everywhere (no auto-increment).
-- - Soft delete (deleted_at) + hard-delete prevention triggers on business tables.
-- - Client-side timestamps: created_at/updated_at are REQUIRED and must be provided by the client (UTC).
-- - Idempotent UPSERT with "updated_at monotonic" guard (LWW by device timestamp).
-- - Snapshotting for sale_items.
-- - Cursor-based delta pull helpers.
-- - Media/storage separation support (media_objects).
-- - Negative inventory logging (CONFLICT_WARNING) without blocking sales.
-- - Schema version gate helpers (for Edge Functions).
--
-- What this script does NOT include
-- - Full RLS/policy model (depends on your auth + tenant strategy).
-- - The Edge Function code itself (but the DB gate function is provided).
-- - A full set of all POS domain tables (extend the same pattern).
--
-- IMPORTANT
-- - created_at/updated_at are device timestamps. Do NOT set them with NOW() in triggers.
-- - For observability, server_received_at is stored separately (server time).
-- - For performance, keep delta sync indexes: (tenant_id, updated_at, id).

begin;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0) Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12) Schema Versioning & Migration Gate (server-side state)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.app_schema_state (
  id int primary key check (id = 1),
  current_version int not null,
  min_supported_version int not null,
  force_update_below_min boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.app_schema_state (id, current_version, min_supported_version)
values (1, 1, 1)
on conflict (id) do nothing;

create table if not exists public.app_schema_migrations (
  from_version int not null,
  to_version int not null,
  migration_script text not null,
  sha256 text,
  created_at timestamptz not null default now(),
  primary key (from_version, to_version)
);

create or replace function public.offline_first_sync_gate(p_client_schema_version int)
returns jsonb
language plpgsql
as $$
declare
  v_current int;
  v_min int;
  v_force boolean;
begin
  select current_version, min_supported_version, force_update_below_min
    into v_current, v_min, v_force
  from public.app_schema_state
  where id = 1;

  if v_current is null then
    return jsonb_build_object(
      'ok', false,
      'action', 'server_misconfigured',
      'message', 'app_schema_state row missing'
    );
  end if;

  if p_client_schema_version is null then
    return jsonb_build_object(
      'ok', false,
      'action', 'schema_version_required',
      'current_version', v_current,
      'min_supported_version', v_min
    );
  end if;

  if p_client_schema_version < v_min then
    return jsonb_build_object(
      'ok', false,
      'action', case when v_force then 'force_update' else 'migration_required' end,
      'current_version', v_current,
      'min_supported_version', v_min
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'action', 'ok',
    'current_version', v_current,
    'min_supported_version', v_min
  );
end;
$$;

revoke all on function public.offline_first_sync_gate(int) from public;
grant execute on function public.offline_first_sync_gate(int) to authenticated;
grant execute on function public.offline_first_sync_gate(int) to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1,6) Multi-tenant core (minimal)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.devices (
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
-- 2,7,9) Idempotency receipts + server-side error sink (DLQ visibility)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.sync_op_receipts (
  op_id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  client_seq bigint not null,
  table_name text not null,
  action text not null check (action in ('upsert', 'soft_delete')),
  row_id uuid not null,
  applied_at timestamptz not null default now(),
  result jsonb not null default '{}'::jsonb
);
create unique index if not exists sync_op_receipts_device_seq_uniq
  on public.sync_op_receipts (device_id, client_seq);

create table if not exists public.sync_batches (
  batch_id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  schema_version int not null,
  client_sent_at timestamptz,
  server_received_at timestamptz not null default now(),
  status text not null default 'running' check (status in ('running', 'ok', 'rejected', 'error')),
  error_message text,
  stats jsonb not null default '{}'::jsonb,
  finished_at timestamptz
);
create index if not exists sync_batches_tenant_received_idx
  on public.sync_batches (tenant_id, server_received_at desc);

create table if not exists public.sync_errors (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  device_id uuid references public.devices(id) on delete set null,
  batch_id uuid,
  op_id uuid,
  table_name text,
  error_code text,
  error_message text not null,
  payload jsonb,
  created_at timestamptz not null default now()
);
create index if not exists sync_errors_tenant_created_idx
  on public.sync_errors (tenant_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) Hard delete prevention (business tables)
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.trg_prevent_hard_delete()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Hard delete is not allowed on %.%', TG_TABLE_SCHEMA, TG_TABLE_NAME;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11) Inventory conflict logging (admin-visible)
-- ─────────────────────────────────────────────────────────────────────────────
create type if not exists public.inventory_log_tag as enum ('NORMAL', 'CONFLICT_WARNING');

create table if not exists public.inventory_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  product_id uuid,
  tag public.inventory_log_tag not null,
  message text not null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create index if not exists inventory_logs_delta_idx
  on public.inventory_logs (tenant_id, updated_at, id);

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
-- 10) Media / Storage separation
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
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create unique index if not exists media_objects_bucket_path_uniq
  on public.media_objects (bucket, object_path);
create index if not exists media_objects_delta_idx
  on public.media_objects (tenant_id, updated_at, id);

-- ─────────────────────────────────────────────────────────────────────────────
-- Business Tables (example set)
-- Apply the same pattern to all POS tables:
-- - id uuid PK
-- - tenant_id
-- - created_at/updated_at (device, required)
-- - deleted_at (soft delete)
-- - server_received_at (server time, optional)
-- - delta index (tenant_id, updated_at, id)
-- - prevent hard delete trigger
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.products (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  sku text,
  name text not null,
  image_url text,
  price numeric(18,2) not null default 0,
  vat_rate numeric(6,3) not null default 0,
  currency text not null default 'TRY',
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create index if not exists products_delta_idx
  on public.products (tenant_id, updated_at, id);
create trigger trg_products_prevent_delete
  before delete on public.products
  for each row execute function public.trg_prevent_hard_delete();

create table if not exists public.sales (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  receipt_no text,
  total_gross numeric(18,2) not null default 0,
  currency text not null default 'TRY',
  note text,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create index if not exists sales_delta_idx
  on public.sales (tenant_id, updated_at, id);
create trigger trg_sales_prevent_delete
  before delete on public.sales
  for each row execute function public.trg_prevent_hard_delete();

create table if not exists public.sale_items (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  sale_id uuid not null references public.sales(id),
  product_id uuid,
  quantity numeric(18,3) not null default 0,
  -- 5) Snapshotting (hard copy)
  product_name_snapshot text not null,
  sku_snapshot text,
  unit_price_snapshot numeric(18,2) not null,
  vat_rate_snapshot numeric(6,3) not null,
  currency_snapshot text not null default 'TRY',
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create index if not exists sale_items_delta_idx
  on public.sale_items (tenant_id, updated_at, id);
create index if not exists sale_items_sale_idx
  on public.sale_items (sale_id);
create trigger trg_sale_items_prevent_delete
  before delete on public.sale_items
  for each row execute function public.trg_prevent_hard_delete();

-- Inventory event table (immutable event style recommended)
create table if not exists public.stock_movements (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  product_id uuid not null,
  quantity_delta numeric(18,3) not null,
  movement_type text not null, -- e.g. 'sale', 'purchase', 'adjustment'
  ref_sale_id uuid,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_received_at timestamptz not null default now(),
  check (updated_at >= created_at)
);
create index if not exists stock_movements_delta_idx
  on public.stock_movements (tenant_id, updated_at, id);
create index if not exists stock_movements_product_idx
  on public.stock_movements (tenant_id, product_id, created_at desc);
create trigger trg_stock_movements_prevent_delete
  before delete on public.stock_movements
  for each row execute function public.trg_prevent_hard_delete();

-- Fast stock cache (server-managed, derived). Not part of the sync protocol.
create table if not exists public.product_stock_cache (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  product_id uuid not null,
  quantity numeric(18,3) not null default 0,
  updated_at timestamptz not null default now(),
  primary key (tenant_id, product_id)
);

create or replace function public.trg_apply_stock_movement_to_cache()
returns trigger
language plpgsql
as $$
declare
  v_delta numeric(18,3);
  v_new_qty numeric(18,3);
begin
  -- Enforce immutability of core movement fields (corrections should be new rows).
  if (tg_op = 'UPDATE') then
    if (old.product_id is distinct from new.product_id)
      or (old.quantity_delta is distinct from new.quantity_delta)
      or (old.movement_type is distinct from new.movement_type)
      or (old.ref_sale_id is distinct from new.ref_sale_id)
    then
      raise exception 'stock_movements rows are immutable (except deleted_at)';
    end if;
  end if;

  v_delta := 0;
  if (tg_op = 'INSERT') then
    if new.deleted_at is null then
      v_delta := new.quantity_delta;
    end if;
  elsif (tg_op = 'UPDATE') then
    if (old.deleted_at is null and new.deleted_at is not null) then
      v_delta := -1 * old.quantity_delta;
    elsif (old.deleted_at is not null and new.deleted_at is null) then
      v_delta := new.quantity_delta;
    else
      v_delta := 0;
    end if;
  end if;

  if v_delta <> 0 then
    insert into public.product_stock_cache (tenant_id, product_id, quantity)
    values (new.tenant_id, new.product_id, v_delta)
    on conflict (tenant_id, product_id)
    do update set
      quantity = public.product_stock_cache.quantity + excluded.quantity,
      updated_at = now()
    returning quantity into v_new_qty;

    if v_new_qty < 0 then
      insert into public.inventory_logs (
        tenant_id, product_id, tag, message, meta,
        created_at, updated_at, deleted_at
      ) values (
        new.tenant_id,
        new.product_id,
        'CONFLICT_WARNING',
        'Negative stock detected (sale is allowed; needs review).',
        jsonb_build_object(
          'movement_id', new.id,
          'movement_type', new.movement_type,
          'delta', v_delta,
          'new_quantity', v_new_qty
        ),
        new.created_at,
        new.updated_at,
        null
      );

      insert into public.admin_notifications (
        tenant_id, type, severity, title, body, metadata
      ) values (
        new.tenant_id,
        'inventory_conflict',
        'warning',
        'Negative stock (CONFLICT_WARNING)',
        'A stock movement caused negative inventory. Sales are not blocked; please review.',
        jsonb_build_object('product_id', new.product_id, 'movement_id', new.id, 'quantity', v_new_qty)
      );
    end if;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_stock_movements_apply_cache on public.stock_movements;
create trigger trg_stock_movements_apply_cache
  after insert or update on public.stock_movements
  for each row execute function public.trg_apply_stock_movement_to_cache();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2,8) Typed UPSERT helpers (LWW by device updated_at) for business tables
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.offline_first_upsert_product(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  v_id := (p_row->>'id')::uuid;
  insert into public.products (
    id, tenant_id, sku, name, image_url, price, vat_rate, currency,
    created_at, updated_at, deleted_at
  ) values (
    v_id,
    (p_row->>'tenant_id')::uuid,
    nullif(p_row->>'sku', ''),
    (p_row->>'name'),
    nullif(p_row->>'image_url', ''),
    coalesce((p_row->>'price')::numeric, 0),
    coalesce((p_row->>'vat_rate')::numeric, 0),
    coalesce(nullif(p_row->>'currency', ''), 'TRY'),
    (p_row->>'created_at')::timestamptz,
    (p_row->>'updated_at')::timestamptz,
    case when nullif(p_row->>'deleted_at', '') is null then null else (p_row->>'deleted_at')::timestamptz end
  )
  on conflict (id) do update set
    tenant_id = excluded.tenant_id,
    sku = excluded.sku,
    name = excluded.name,
    image_url = excluded.image_url,
    price = excluded.price,
    vat_rate = excluded.vat_rate,
    currency = excluded.currency,
    created_at = excluded.created_at,
    updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at,
    server_received_at = now()
  where excluded.updated_at >= public.products.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_soft_delete_product(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_tenant uuid;
  v_updated_at timestamptz;
  v_deleted_at timestamptz;
begin
  v_id := (p_row->>'id')::uuid;
  v_tenant := (p_row->>'tenant_id')::uuid;
  v_updated_at := (p_row->>'updated_at')::timestamptz;
  v_deleted_at := (p_row->>'deleted_at')::timestamptz;

  update public.products
  set deleted_at = v_deleted_at,
      updated_at = v_updated_at,
      server_received_at = now()
  where id = v_id
    and tenant_id = v_tenant
    and v_updated_at >= public.products.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_upsert_sale(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  v_id := (p_row->>'id')::uuid;
  insert into public.sales (
    id, tenant_id, receipt_no, total_gross, currency, note,
    created_at, updated_at, deleted_at
  ) values (
    v_id,
    (p_row->>'tenant_id')::uuid,
    nullif(p_row->>'receipt_no', ''),
    coalesce((p_row->>'total_gross')::numeric, 0),
    coalesce(nullif(p_row->>'currency', ''), 'TRY'),
    nullif(p_row->>'note', ''),
    (p_row->>'created_at')::timestamptz,
    (p_row->>'updated_at')::timestamptz,
    case when nullif(p_row->>'deleted_at', '') is null then null else (p_row->>'deleted_at')::timestamptz end
  )
  on conflict (id) do update set
    tenant_id = excluded.tenant_id,
    receipt_no = excluded.receipt_no,
    total_gross = excluded.total_gross,
    currency = excluded.currency,
    note = excluded.note,
    created_at = excluded.created_at,
    updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at,
    server_received_at = now()
  where excluded.updated_at >= public.sales.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_soft_delete_sale(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_tenant uuid;
  v_updated_at timestamptz;
  v_deleted_at timestamptz;
begin
  v_id := (p_row->>'id')::uuid;
  v_tenant := (p_row->>'tenant_id')::uuid;
  v_updated_at := (p_row->>'updated_at')::timestamptz;
  v_deleted_at := (p_row->>'deleted_at')::timestamptz;

  update public.sales
  set deleted_at = v_deleted_at,
      updated_at = v_updated_at,
      server_received_at = now()
  where id = v_id
    and tenant_id = v_tenant
    and v_updated_at >= public.sales.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_upsert_sale_item(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  v_id := (p_row->>'id')::uuid;
  insert into public.sale_items (
    id, tenant_id, sale_id, product_id, quantity,
    product_name_snapshot, sku_snapshot, unit_price_snapshot, vat_rate_snapshot, currency_snapshot,
    created_at, updated_at, deleted_at
  ) values (
    v_id,
    (p_row->>'tenant_id')::uuid,
    (p_row->>'sale_id')::uuid,
    case when nullif(p_row->>'product_id', '') is null then null else (p_row->>'product_id')::uuid end,
    coalesce((p_row->>'quantity')::numeric, 0),
    (p_row->>'product_name_snapshot'),
    nullif(p_row->>'sku_snapshot', ''),
    coalesce((p_row->>'unit_price_snapshot')::numeric, 0),
    coalesce((p_row->>'vat_rate_snapshot')::numeric, 0),
    coalesce(nullif(p_row->>'currency_snapshot', ''), 'TRY'),
    (p_row->>'created_at')::timestamptz,
    (p_row->>'updated_at')::timestamptz,
    case when nullif(p_row->>'deleted_at', '') is null then null else (p_row->>'deleted_at')::timestamptz end
  )
  on conflict (id) do update set
    tenant_id = excluded.tenant_id,
    sale_id = excluded.sale_id,
    product_id = excluded.product_id,
    quantity = excluded.quantity,
    product_name_snapshot = excluded.product_name_snapshot,
    sku_snapshot = excluded.sku_snapshot,
    unit_price_snapshot = excluded.unit_price_snapshot,
    vat_rate_snapshot = excluded.vat_rate_snapshot,
    currency_snapshot = excluded.currency_snapshot,
    created_at = excluded.created_at,
    updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at,
    server_received_at = now()
  where excluded.updated_at >= public.sale_items.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_soft_delete_sale_item(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_tenant uuid;
  v_updated_at timestamptz;
  v_deleted_at timestamptz;
begin
  v_id := (p_row->>'id')::uuid;
  v_tenant := (p_row->>'tenant_id')::uuid;
  v_updated_at := (p_row->>'updated_at')::timestamptz;
  v_deleted_at := (p_row->>'deleted_at')::timestamptz;

  update public.sale_items
  set deleted_at = v_deleted_at,
      updated_at = v_updated_at,
      server_received_at = now()
  where id = v_id
    and tenant_id = v_tenant
    and v_updated_at >= public.sale_items.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_upsert_stock_movement(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  v_id := (p_row->>'id')::uuid;
  insert into public.stock_movements (
    id, tenant_id, product_id, quantity_delta, movement_type, ref_sale_id,
    created_at, updated_at, deleted_at
  ) values (
    v_id,
    (p_row->>'tenant_id')::uuid,
    (p_row->>'product_id')::uuid,
    (p_row->>'quantity_delta')::numeric,
    (p_row->>'movement_type'),
    case when nullif(p_row->>'ref_sale_id', '') is null then null else (p_row->>'ref_sale_id')::uuid end,
    (p_row->>'created_at')::timestamptz,
    (p_row->>'updated_at')::timestamptz,
    case when nullif(p_row->>'deleted_at', '') is null then null else (p_row->>'deleted_at')::timestamptz end
  )
  on conflict (id) do update set
    tenant_id = excluded.tenant_id,
    product_id = excluded.product_id,
    quantity_delta = excluded.quantity_delta,
    movement_type = excluded.movement_type,
    ref_sale_id = excluded.ref_sale_id,
    created_at = excluded.created_at,
    updated_at = excluded.updated_at,
    deleted_at = excluded.deleted_at,
    server_received_at = now()
  where excluded.updated_at >= public.stock_movements.updated_at;

  return v_id;
end;
$$;

create or replace function public.offline_first_soft_delete_stock_movement(p_row jsonb)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
  v_tenant uuid;
  v_updated_at timestamptz;
  v_deleted_at timestamptz;
begin
  v_id := (p_row->>'id')::uuid;
  v_tenant := (p_row->>'tenant_id')::uuid;
  v_updated_at := (p_row->>'updated_at')::timestamptz;
  v_deleted_at := (p_row->>'deleted_at')::timestamptz;

  update public.stock_movements
  set deleted_at = v_deleted_at,
      updated_at = v_updated_at,
      server_received_at = now()
  where id = v_id
    and tenant_id = v_tenant
    and v_updated_at >= public.stock_movements.updated_at;

  return v_id;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7,8) Apply batch (max 50 ops) in a single transaction
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.offline_first_apply_batch(
  p_tenant_id uuid,
  p_device_id uuid,
  p_schema_version int,
  p_batch_id uuid,
  p_client_sent_at timestamptz,
  p_ops jsonb
)
returns jsonb
language plpgsql
as $$
declare
  v_gate jsonb;
  v_count int;
  v_existing_status text;
  v_applied int := 0;
  v_skipped int := 0;
  v_op jsonb;
  v_op_id uuid;
  v_client_seq bigint;
  v_table text;
  v_action text;
  v_row_id uuid;
begin
  v_gate := public.offline_first_sync_gate(p_schema_version);
  if (coalesce((v_gate->>'ok')::boolean, false) = false) then
    insert into public.sync_batches (
      batch_id, tenant_id, device_id, schema_version, client_sent_at, status, stats, finished_at
    ) values (
      p_batch_id, p_tenant_id, p_device_id, coalesce(p_schema_version, 0), p_client_sent_at,
      'rejected',
      jsonb_build_object('gate', v_gate),
      now()
    )
    on conflict (batch_id) do nothing;

    return v_gate;
  end if;

  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then
    raise exception 'p_ops must be a json array';
  end if;

  v_count := jsonb_array_length(p_ops);
  if v_count > 50 then
    raise exception 'batch too large (max 50)';
  end if;

  insert into public.sync_batches (
    batch_id, tenant_id, device_id, schema_version, client_sent_at, status
  ) values (
    p_batch_id, p_tenant_id, p_device_id, p_schema_version, p_client_sent_at, 'running'
  )
  on conflict (batch_id) do nothing;

  select status into v_existing_status from public.sync_batches where batch_id = p_batch_id;
  if v_existing_status = 'ok' then
    return (select stats from public.sync_batches where batch_id = p_batch_id);
  end if;

  for v_op in select * from jsonb_array_elements(p_ops) loop
    v_op_id := (v_op->>'op_id')::uuid;
    v_client_seq := (v_op->>'client_seq')::bigint;
    v_table := (v_op->>'table');
    v_action := (v_op->>'action');
    v_row_id := (v_op->>'row_id')::uuid;

    if v_op_id is null then
      raise exception 'op_id is required';
    end if;

    insert into public.sync_op_receipts (
      op_id, tenant_id, device_id, client_seq, table_name, action, row_id
    ) values (
      v_op_id, p_tenant_id, p_device_id, v_client_seq, v_table, v_action, v_row_id
    )
    on conflict (op_id) do nothing;

    if not found then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if v_action = 'upsert' then
      if v_table = 'products' then
        perform public.offline_first_upsert_product(v_op->'data');
      elsif v_table = 'sales' then
        perform public.offline_first_upsert_sale(v_op->'data');
      elsif v_table = 'sale_items' then
        perform public.offline_first_upsert_sale_item(v_op->'data');
      elsif v_table = 'stock_movements' then
        perform public.offline_first_upsert_stock_movement(v_op->'data');
      elsif v_table = 'media_objects' then
        insert into public.media_objects (
          id, tenant_id, bucket, object_path, public_url, mime_type, size_bytes, sha256, status,
          created_at, updated_at, deleted_at
        ) values (
          (v_op->'data'->>'id')::uuid,
          (v_op->'data'->>'tenant_id')::uuid,
          coalesce(nullif(v_op->'data'->>'bucket', ''), 'media'),
          (v_op->'data'->>'object_path'),
          nullif(v_op->'data'->>'public_url', ''),
          nullif(v_op->'data'->>'mime_type', ''),
          case when nullif(v_op->'data'->>'size_bytes', '') is null then null else (v_op->'data'->>'size_bytes')::bigint end,
          nullif(v_op->'data'->>'sha256', ''),
          coalesce(nullif(v_op->'data'->>'status', ''), 'uploaded'),
          (v_op->'data'->>'created_at')::timestamptz,
          (v_op->'data'->>'updated_at')::timestamptz,
          case when nullif(v_op->'data'->>'deleted_at', '') is null then null else (v_op->'data'->>'deleted_at')::timestamptz end
        )
        on conflict (id) do update set
          tenant_id = excluded.tenant_id,
          bucket = excluded.bucket,
          object_path = excluded.object_path,
          public_url = excluded.public_url,
          mime_type = excluded.mime_type,
          size_bytes = excluded.size_bytes,
          sha256 = excluded.sha256,
          status = excluded.status,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at,
          server_received_at = now()
        where excluded.updated_at >= public.media_objects.updated_at;
      else
        insert into public.sync_errors (
          tenant_id, device_id, batch_id, op_id, table_name, error_code, error_message, payload
        ) values (
          p_tenant_id, p_device_id, p_batch_id, v_op_id, v_table,
          'UNSUPPORTED_TABLE',
          'Unsupported table in batch',
          v_op
        );
        raise exception 'Unsupported table in batch: %', v_table;
      end if;
    elsif v_action = 'soft_delete' then
      if v_table = 'products' then
        perform public.offline_first_soft_delete_product(v_op->'data');
      elsif v_table = 'sales' then
        perform public.offline_first_soft_delete_sale(v_op->'data');
      elsif v_table = 'sale_items' then
        perform public.offline_first_soft_delete_sale_item(v_op->'data');
      elsif v_table = 'stock_movements' then
        perform public.offline_first_soft_delete_stock_movement(v_op->'data');
      elsif v_table = 'media_objects' then
        update public.media_objects
        set deleted_at = (v_op->'data'->>'deleted_at')::timestamptz,
            updated_at = (v_op->'data'->>'updated_at')::timestamptz,
            server_received_at = now()
        where id = (v_op->'data'->>'id')::uuid
          and tenant_id = (v_op->'data'->>'tenant_id')::uuid
          and ((v_op->'data'->>'updated_at')::timestamptz) >= public.media_objects.updated_at;
      else
        insert into public.sync_errors (
          tenant_id, device_id, batch_id, op_id, table_name, error_code, error_message, payload
        ) values (
          p_tenant_id, p_device_id, p_batch_id, v_op_id, v_table,
          'UNSUPPORTED_TABLE',
          'Unsupported table in batch',
          v_op
        );
        raise exception 'Unsupported table in batch: %', v_table;
      end if;
    else
      raise exception 'Unsupported action in batch: %', v_action;
    end if;

    v_applied := v_applied + 1;
  end loop;

  update public.sync_batches
  set status = 'ok',
      stats = jsonb_build_object(
        'ok', true,
        'applied', v_applied,
        'skipped', v_skipped
      ),
      finished_at = now()
  where batch_id = p_batch_id;

  return jsonb_build_object('ok', true, 'applied', v_applied, 'skipped', v_skipped);
exception when others then
  update public.sync_batches
  set status = 'error',
      error_message = sqlerrm,
      stats = jsonb_build_object('ok', false, 'error', sqlerrm),
      finished_at = now()
  where batch_id = p_batch_id;
  raise;
end;
$$;

revoke all on function public.offline_first_apply_batch(uuid, uuid, int, uuid, timestamptz, jsonb) from public;
grant execute on function public.offline_first_apply_batch(uuid, uuid, int, uuid, timestamptz, jsonb) to service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10) Cursor-based delta pull helpers (example)
-- NOTE: Do NOT filter deleted_at here; you must pull tombstones too.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.offline_first_pull_products_delta(
  p_tenant_id uuid,
  p_since timestamptz,
  p_after_id uuid default null,
  p_limit int default 1000
)
returns setof public.products
language sql
stable
as $$
  select *
  from public.products
  where tenant_id = p_tenant_id
    and (
      updated_at > coalesce(p_since, 'epoch'::timestamptz)
      or (
        updated_at = coalesce(p_since, 'epoch'::timestamptz)
        and p_after_id is not null
        and id > p_after_id
      )
    )
  order by updated_at asc, id asc
  limit greatest(1, least(p_limit, 5000));
$$;

create or replace function public.offline_first_pull_sales_delta(
  p_tenant_id uuid,
  p_since timestamptz,
  p_after_id uuid default null,
  p_limit int default 1000
)
returns setof public.sales
language sql
stable
as $$
  select *
  from public.sales
  where tenant_id = p_tenant_id
    and (
      updated_at > coalesce(p_since, 'epoch'::timestamptz)
      or (
        updated_at = coalesce(p_since, 'epoch'::timestamptz)
        and p_after_id is not null
        and id > p_after_id
      )
    )
  order by updated_at asc, id asc
  limit greatest(1, least(p_limit, 5000));
$$;

create or replace function public.offline_first_pull_sale_items_delta(
  p_tenant_id uuid,
  p_since timestamptz,
  p_after_id uuid default null,
  p_limit int default 1000
)
returns setof public.sale_items
language sql
stable
as $$
  select *
  from public.sale_items
  where tenant_id = p_tenant_id
    and (
      updated_at > coalesce(p_since, 'epoch'::timestamptz)
      or (
        updated_at = coalesce(p_since, 'epoch'::timestamptz)
        and p_after_id is not null
        and id > p_after_id
      )
    )
  order by updated_at asc, id asc
  limit greatest(1, least(p_limit, 5000));
$$;

create or replace function public.offline_first_pull_stock_movements_delta(
  p_tenant_id uuid,
  p_since timestamptz,
  p_after_id uuid default null,
  p_limit int default 1000
)
returns setof public.stock_movements
language sql
stable
as $$
  select *
  from public.stock_movements
  where tenant_id = p_tenant_id
    and (
      updated_at > coalesce(p_since, 'epoch'::timestamptz)
      or (
        updated_at = coalesce(p_since, 'epoch'::timestamptz)
        and p_after_id is not null
        and id > p_after_id
      )
    )
  order by updated_at asc, id asc
  limit greatest(1, least(p_limit, 5000));
$$;

commit;
