#!/bin/bash
# PostgreSQL 18 Kurulum ve Hazırlık Scripti
# Bu script mevcut PostgreSQL sürümünü bozmadan yanına v18 kurar veya yükseltir.

set -e

echo "🚀 PostgreSQL 18 Hazırlık Scripti Başlatılıyor..."

# 1. Homebrew Kontrolü
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew bulunamadı! Lütfen önce Homebrew kurun."
    exit 1
fi

echo "📦 Mevcut PostgreSQL servisleri kontrol ediliyor..."
brew services list

# 2. PostgreSQL 18 Kurulumu
echo "⬇️ PostgreSQL 18 indiriliyor ve kuruluyor..."
# Not: Homebrew tarafında `postgresql@18` görünmüyorsa (tap/mirror gecikmesi vb.),
# `postgresql` (latest) denenir.
if brew install postgresql@18 2>/dev/null; then
    echo "✅ PostgreSQL 18 başarıyla kuruldu."
else
    echo "⚠️ PostgreSQL 18 paketi bulunamadı, 'postgresql' (latest) deneniyor..."
    brew install postgresql
fi

# 3. Servis Başlatma
echo "🔄 PostgreSQL servisi başlatılıyor..."
brew services start postgresql@18 || brew services start postgresql

echo "🎉 Kurulum Tamamlandı!"
echo "⚠️ ÖNEMLİ: Veritabanı verilerinizi taşımak (Migration) için veritabanı yedeğini (dump) yeni sunucuya yüklemelisiniz."
echo "ℹ️ Bağlantı ayarlarınızı (Port vs.) kontrol etmeyin unutmayın."

echo ""
echo "⚠️ PostgreSQL 18 UPGRADE NOTU (pg_trgm / FTS / collation)"
echo "PG18'de Full Text Search, sözlük/config okurken artık cluster'ın default collation provider'ını kullanır."
echo "Eğer cluster default collation provider'ı libc değilse (ICU/builtin) ve yükseltmeyi pg_upgrade ile yaptıysan,"
echo "FTS ve pg_trgm ile ilgili indeksleri REINDEX etmen önerilir."
echo ""
echo "Ayrıca OS/ICU upgrade sonrası collation version mismatch uyarısı görürsen:"
echo "1) REINDEX (etkilenen indeksler veya tüm DB)"
echo "2) ALTER DATABASE ... REFRESH COLLATION VERSION"
echo ""
echo "Örnek (db owner/superuser):"
echo "  psql -d <db> -c \"REINDEX (VERBOSE) DATABASE \\\"<db>\\\";\""
echo "  psql -d <db> -c \"ALTER DATABASE \\\"<db>\\\" REFRESH COLLATION VERSION;\""
