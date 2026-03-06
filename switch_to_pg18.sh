#!/bin/bash
set -e

echo "🔄 PostgreSQL 14 -> 18 Geçişi Başlatılıyor (Temiz Kurulum)..."

# 1. Eski Sürümü Durdur ve Kaldır
if brew list postgresql@14 &>/dev/null; then
    echo "🛑 PostgreSQL 14 durduruluyor..."
    brew services stop postgresql@14 || true
    echo "🗑️ PostgreSQL 14 kaldırılıyor..."
    brew uninstall postgresql@14
else
    echo "ℹ️ PostgreSQL 14 zaten yüklü değil."
fi

# 'postgresql' (alias) servisi varsa durdur
brew services stop postgresql || true

# 2. PostgreSQL 18'i Başlat ve Linkle
echo "🚀 PostgreSQL 18 başlatılıyor..."
brew services start postgresql@18

echo "🔗 Komut satırı araçları (psql) linkleniyor..."
brew link --overwrite --force postgresql@18

# Servisin ayağa kalkmasını bekle
echo "⏳ Servis bekleniyor..."
sleep 5

# 3. Kullanıcı ve Veritabanı Yapılandırması (Proje Varsayılanları)
# Proje 'patisyo' kullanıcısı ile çalışır. Şifreyi istersen
# `PATISYO_PG_PASSWORD` env değişkeni ile otomatik ayarlatabilirsin.

PATISYO_PASSWORD="${PATISYO_PG_PASSWORD:-}"
if [ -z "$PATISYO_PASSWORD" ]; then
    echo "ℹ️ PATISYO_PG_PASSWORD yok; 'patisyo' şifresi ayarlanmayacak."
fi

CURRENT_USER=$(whoami)
echo "👤 Mevcut kullanıcı: $CURRENT_USER"

# 'patisyo' kullanıcısını oluştur (Superuser yetkisiyle, böylece DB oluşturabilir)
if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='patisyo'" | grep -q 1; then
    echo "✨ 'patisyo' kullanıcısı oluşturuluyor..."
    createuser -s patisyo
    if [ -n "$PATISYO_PASSWORD" ]; then
        psql postgres -c "ALTER USER patisyo WITH PASSWORD '$PATISYO_PASSWORD';"
    fi
else
    echo "✅ 'patisyo' kullanıcısı zaten var."
    # Şifreyi garantiye al (opsiyonel)
    if [ -n "$PATISYO_PASSWORD" ]; then
        psql postgres -c "ALTER USER patisyo WITH PASSWORD '$PATISYO_PASSWORD';"
    fi
fi

# 'patisyosettings' veritabanını oluştur (Eğer yoksa)
if ! psql -lqt | cut -d \| -f 1 | grep -qw patisyosettings; then
    echo "📂 'patisyosettings' veritabanı oluşturuluyor..."
    createdb -O patisyo patisyosettings
else
    echo "✅ 'patisyosettings' veritabanı zaten var."
fi

# 4. Yetkilendirme
# 'pateez' (admin connection) için de yetki verelim ki uygulama ilk kurulumu yapabilsin
psql postgres -c "ALTER USER \"$CURRENT_USER\" WITH CREATEDB CREATEROLE;" || true

echo "🎉 İŞLEM TAMAMLANDI! PostgreSQL 18 artık aktif ve proje için hazır."
echo "✅ Eski sürüm kaldırıldı."
echo "✅ Yeni sürüm (boş) başlatıldı."
echo "✅ 'patisyo' kullanıcısı ve DB ayarlandı."

echo ""
echo "⚠️ PostgreSQL 18 UPGRADE NOTU (pg_trgm / FTS / collation)"
echo "Bu script 'temiz kurulum' yapar (eski data taşınmaz). Eğer mevcut cluster'ı pg_upgrade ile yükseltiyorsan:"
echo "- Default collation provider libc değilse (ICU/builtin) PG18'de FTS+pg_trgm indeksleri REINDEX gerekebilir."
echo "- OS/ICU upgrade sonrası collation version mismatch uyarısı görürsen REINDEX + REFRESH COLLATION VERSION uygula."
echo ""
echo "Örnek (db owner/superuser):"
echo "  psql -d <db> -c \"REINDEX (VERBOSE) DATABASE \\\"<db>\\\";\""
echo "  psql -d <db> -c \"ALTER DATABASE \\\"<db>\\\" REFRESH COLLATION VERSION;\""
