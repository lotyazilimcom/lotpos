# Offline‑First POS — `SyncManager` Pseudo‑Code (Flutter)

Tarih: 2026‑02‑22  
Hedef: Flutter + Supabase (PostgreSQL) ile **finansal hata toleransı SIFIR** bir POS’ta, offline‑first senkronizasyonun güvenli/ölçeklenebilir iskeleti.

Bu doküman; UUID, Soft Delete, Snapshotting, Queue + (8‑12) ileri seviye kuralları kapsayan **mantıksal/pseudo** bir taslaktır. Uygulama detaylarını repo’daki mevcut DB erişim mimarinizle (Postgres direkt bağlantı / Supabase / Local DB) uyarlamanız gerekir.

İlgili server şeması referansı: `docs/OFFLINE_FIRST_SUPABASE_SYNC_SCHEMA.sql`

---

## 0) Terminoloji

- **Local DB:** Cihaz içi kalıcı store (örn. SQLite/Drift). Offline gerçekliği burasıdır.
- **Cloud DB:** Supabase Postgres (tenant başına tek DB ya da shared schema).
- **Outbox Queue:** Local DB’de “gönderilecek işlemler” kuyruğu.
- **Cursor:** Her tablo için `(last_pulled_at, last_pulled_id)`; delta sync için kullanılır.
- **Op Receipt:** Server’ın “bu op daha önce uygulandı” dedirten idempotency kaydı.
- **Schema Version:** Client tarafının DB/Entity şema sürümü.

---

## 1) Edge Function sözleşmesi (Rule 8 + Rule 9)

### Request (örnek)

```
POST /functions/v1/sync
Headers:
  Authorization: Bearer <jwt/service-token>
  X-Tenant-Id: <uuid>
  X-Device-Id: <uuid>
  X-Schema-Version: <int>
Body:
{
  "client_time": "2026-02-22T12:00:00Z",
  "push": [
    {
      "op_id": "uuid",
      "client_seq": 1234,
      "table": "sales",
      "action": "upsert",
      "row_id": "uuid",
      "payload": { ... },        // JSON row
      "base_row_version": 7      // optional optimistic lock
    }
  ],
  "cursors": {
    "products": { "ts": "2026-02-20T10:00:00Z", "id": "uuid" },
    "sales":    { "ts": "2026-02-20T10:00:00Z", "id": "uuid" }
  },
  "limits": { "per_table": 1000 }
}
```

### Response (örnek)

```
200 OK
{
  "server_time": "2026-02-22T12:00:01Z",
  "ack": ["op_id_1", "op_id_2"],
  "pull": {
    "products": { "rows": [ ... ], "next_cursor": { "ts": "...", "id": "..." } },
    "sales":    { "rows": [ ... ], "next_cursor": { "ts": "...", "id": "..." } }
  },
  "inventory_warnings": [
    { "tag": "CONFLICT_WARNING", "product_id": "...", "warehouse_id": "...", "qty_after": -1 }
  ]
}
```

### Rule 8 — Schema gate

Edge Function her çağrıda `X-Schema-Version` kontrolü yapar:

- `client_schema_version < min_supported_version`  → **426** “FORCE_UPDATE”
- `min_supported_version <= client < current_version` → **409** “MIGRATION_REQUIRED” (+ script/plan)
- `client >= current_version` → devam

> Finansal güvenlik için pratikte en güvenlisi: “force update” (uygulama içi migration script dağıtmak riskli).

---

## 2) Local veri modeli (Rule 1‑4, 9‑10)

### 2.1 Outbox tablosu (local)

```
outbox(
  op_id uuid primary key,
  client_seq int not null,
  table_name text not null,
  action text not null,        // upsert|delete
  row_id uuid not null,
  payload json,
  base_row_version int?,       // optimistic lock for mutable master data
  created_at datetime not null,
  attempt_count int not null default 0,
  next_retry_at datetime?,
  last_error text?,
  status text not null         // pending|in_flight|acked|dead
)
```

### 2.2 Cursor tablosu (local)

```
sync_cursors(
  table_name text primary key,
  last_pulled_at datetime not null,
  last_pulled_id uuid?
)
```

### 2.3 Snapshot tablosu (local) (Rule 3)

Sadece kritik tablolar için (sales/payments/ledger/inventory):

```
snapshots(
  id uuid primary key,
  table_name text,
  row_id uuid,
  op_id uuid?,
  before json?,
  after json?,
  created_at datetime
)
```

### 2.4 Media kuyruğu (Rule 10)

```
media_queue(
  id uuid primary key,
  tenant_id uuid,
  local_path text,
  bucket text,
  object_path text,
  mime_type text,
  sha256 text,
  status text,                 // pending|uploaded|failed
  public_url text?
)
```

---

## 3) `MediaStoreService` (Rule 10)

Amaç: Görsel/ikili dosyayı **önce** Supabase Storage’a yükle, sonra DB kuyruğuna sadece `image_url` string’i koy.

```
class MediaStoreService {
  SupabaseClient supabase;
  LocalDb db;

  Future<String> uploadAndGetPublicUrl(MediaQueueItem item) async {
    // 1) Upload (retryable)
    // 2) Verify checksum if possible
    // 3) Get public url (or store path and use signed url)
    // 4) Mark media_queue uploaded
    return publicUrl;
  }

  Future<void> flushPendingUploads({int batchSize = 10}) async {
    if (!await Connectivity.isOnline()) return;

    final items = await db.mediaQueue.getPending(limit: batchSize);
    for (final item in items) {
      try {
        final url = await uploadAndGetPublicUrl(item);
        await db.transaction(() async {
          await db.mediaQueue.markUploaded(item.id, publicUrl: url);
          // Eğer bu medya bir ürün resmine bağlıysa:
          // - product.image_url güncelle
          // - outbox'a upsert op'u ekle (sadece url string)
        });
      } catch (e) {
        await db.mediaQueue.markFailed(item.id, error: e.toString());
      }
    }
  }
}
```

---

## 4) `SyncManager` — yüksek seviyeli pseudo‑code

### 4.1 Yapı (tek giriş noktası + kilit)

```
class SyncManager {
  final LocalDb db;
  final SupabaseClient supabase;
  final MediaStoreService media;

  final Mutex _syncMutex = Mutex();
  final Duration pushTimeout = 30s;
  final Duration pullTimeout = 30s;

  // Client schema version (bundle/build-time sabit)
  final int schemaVersion = kSchemaVersion;

  Future<SyncResult> syncNow({required SyncReason reason}) async {
    return _syncMutex.protect(() => _syncNowLocked(reason));
  }
}
```

### 4.2 Senkron akışı

```
Future<SyncResult> _syncNowLocked(SyncReason reason) async {
  if (!await Connectivity.isOnline()) return SyncResult.skippedOffline();
  if (!await Auth.hasValidToken()) return SyncResult.skippedNoAuth();

  // 10) Media önce
  await media.flushPendingUploads(batchSize: 10);

  // 8) Schema gate handshake (Edge Function)
  final gate = await _schemaGateCheck();
  if (gate.type == FORCE_UPDATE) {
    // UI: bloklayıcı dialog + store link
    return SyncResult.forceUpdate(gate);
  }
  if (gate.type == MIGRATION_REQUIRED) {
    // Lokal migration planı uygula (çok dikkatli!)
    // Finansal güvenlikte genelde force update daha doğru.
    await _runLocalMigrations(gate.migrations);
  }

  // 4) PUSH: outbox -> server
  final pushResult = await _pushOutboxBatches(maxOps: 200);
  if (!pushResult.ok) {
    // backoff scheduling
    return SyncResult.partial(push: pushResult, pull: null);
  }

  // 9) PULL: cursor-based delta per table
  final pullResult = await _pullDeltasAndApply(
    tables: SyncTables.criticalFirst(),
    perTableLimit: 1000,
  );

  // 11) Negatif stok uyarıları (server’dan döner veya logs tablosundan çekilir)
  await _handleInventoryWarnings(pullResult.inventoryWarnings);

  // 3) Snapshotting (opsiyonel): kritik tablolar için audit kaydı
  // Not: snapshot maliyetlidir; sadece gerekli yerde tut.

  await db.syncState.setLastSyncAt(DateTime.now());
  return SyncResult.ok(pushResult, pullResult);
}
```

---

## 5) PUSH detayları (Rule 4 + finansal güvenlik)

Hedef: **At-least-once gönderim**, server’da **exactly-once etki** (op receipt).

```
Future<PushResult> _pushOutboxBatches({required int maxOps}) async {
  while (true) {
    final ops = await db.outbox.getSendableOps(limit: 50, maxTotal: maxOps);
    if (ops.isEmpty) return PushResult.ok();

    // idempotency: op_id sabit olmalı (asla yeniden üretilmemeli)
    final req = SyncRequest(
      schemaVersion: schemaVersion,
      deviceId: DeviceId.current(),
      tenantId: TenantId.current(),
      push: ops,
      cursors: await db.cursors.getAll(),
    );

    SyncResponse res;
    try {
      res = await supabase.functions.invoke("sync", body: req, timeout: pushTimeout);
    } on TimeoutException {
      await db.outbox.bumpRetry(ops, error: "timeout");
      return PushResult.failed("timeout");
    } catch (e) {
      await db.outbox.bumpRetry(ops, error: e.toString());
      return PushResult.failed(e.toString());
    }

    // ACK: sadece ack edilenleri kuyruktan düşür
    await db.transaction(() async {
      await db.outbox.markAcked(opIds: res.ack);
      // Server response pull içeriyorsa aynı transaction içinde apply edebilirsin
    });
  }
}
```

Finansal tablolar için kritik not:

- **UPDATE yerine INSERT‑only event** yaklaşımı (sale/payment/ledger) conflict riskini dramatik azaltır.
- İptal/iade gibi işlemler “yeni event” olarak eklenir (mutasyon yerine).

---

## 6) PULL detayları (Rule 9 + Soft Delete)

```
Future<PullResult> _pullDeltasAndApply({required List<String> tables, required int perTableLimit}) async {
  final cursors = await db.cursors.getAll();

  final req = SyncRequest(
    schemaVersion: schemaVersion,
    deviceId: DeviceId.current(),
    tenantId: TenantId.current(),
    push: [],
    cursors: cursors,
    limits: { per_table: perTableLimit },
  );

  final res = await supabase.functions.invoke("sync", body: req, timeout: pullTimeout);

  await db.transaction(() async {
    for (final table in tables) {
      final page = res.pull[table];
      for (final row in page.rows) {
        if (row.deleted_at != null) {
          await db.applyTombstone(table, row.id, deletedAt: row.deleted_at);
        } else {
          await db.upsertRow(table, row);
        }
      }
      await db.cursors.set(table, page.next_cursor.ts, page.next_cursor.id);
    }
  });

  return PullResult(ok: true, inventoryWarnings: res.inventory_warnings);
}
```

---

## 7) Schema migration güvenliği (Rule 8)

Öneri:

1. Client `schema_version` **build-time sabit** (ör. `const int kSchemaVersion = 12;`).
2. Edge Function, **min_supported_version** altında ise uygulamayı bloklar.
3. Migration script çalıştırmak gerekiyorsa:
   - Script’ler imzalı (sha256 + server-side allowlist) olmalı,
   - Lokal DB migration transaction içinde olmalı,
   - Migrations **idempotent** olmalı,
   - Finansal tablolar için “veri dönüştürme” yerine yeni kolon ekleme tercih edilmeli.

---

## 8) Negatif stok yönetimi (Rule 11)

Kural: “Satış kutsal” → satış engellenmez.

Uygulama:

- Offline satış → local event oluştur + outbox’a ekle.
- Sync sırasında server aynı ürüne paralel satışları uygulayınca stok negatif olabilir:
  - `inventory_logs.tag = CONFLICT_WARNING`
  - `admin_notifications` ile panele bildirim
- Client tarafında:
  - Uyarı sayacı / banner
  - Yöneticiye “stok düzeltme” akışı (adjustment movement)

---

## 9) Background Sync (Rule 12)

### Android — WorkManager

```
void setupBackgroundSyncAndroid() {
  Workmanager().initialize(callbackDispatcher);
  Workmanager().registerPeriodicTask(
    "silentSync",
    "silentSync",
    frequency: 15 minutes,
    constraints: {
      networkType: connected,
      requiresBatteryNotLow: true,
    }
  );
}

void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    await AppBootstrap.ensureInitialized();
    await SyncManager.instance.syncNow(reason: SyncReason.background);
    return Future.value(true);
  });
}
```

### iOS — Background Fetch / BGTask

```
void setupBackgroundSyncIos() {
  BackgroundFetch.configure(
    minimumFetchInterval: 15,
    stopOnTerminate: false,
    enableHeadless: true,
    (taskId) async {
      await AppBootstrap.ensureInitialized();
      await SyncManager.instance.syncNow(reason: SyncReason.background);
      BackgroundFetch.finish(taskId);
    },
  );
}
```

Notlar:

- iOS “15 dk kesin” garantisi vermez; sistem karar verir.
- Background sync yalnızca:
  - Kullanıcı authenticated ise,
  - Local DB hazırsa,
  - Ağ varsa
  çalışmalıdır.

---

## 10) Önerilen senkron stratejisi (Hybrid / Cloud / Local)

- **Local:** Sadece local DB; sync opsiyonel (yedek).
- **Cloud:** Cloud kaynak gerçek; local cache opsiyonel.
- **Hybrid:** Local “source of truth” + cloud’a “yakın gerçek zamanlı” replika:
  - UI işlemleri local transaction ile commit,
  - Outbox ile asenkron push,
  - Kritik event’lerde anlık `syncNow(reason: userAction)`,
  - Arka planda periyodik silent sync.

