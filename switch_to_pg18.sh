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
# Proje 'lospos' kullanıcısı ile çalışır. Şifreyi istersen
# `LOSPOS_PG_PASSWORD` env değişkeni ile otomatik ayarlatabilirsin.

LOSPOS_PASSWORD="${LOSPOS_PG_PASSWORD:-}"
if [ -z "$LOSPOS_PASSWORD" ]; then
    echo "ℹ️ LOSPOS_PG_PASSWORD yok; 'lospos' şifresi ayarlanmayacak."
fi

CURRENT_USER=$(whoami)
echo "👤 Mevcut kullanıcı: $CURRENT_USER"

# 'lospos' kullanıcısını oluştur (Superuser yetkisiyle, böylece DB oluşturabilir)
if ! psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='lospos'" | grep -q 1; then
    echo "✨ 'lospos' kullanıcısı oluşturuluyor..."
    createuser -s lospos
    if [ -n "$LOSPOS_PASSWORD" ]; then
        psql postgres -c "ALTER USER lospos WITH PASSWORD '$LOSPOS_PASSWORD';"
    fi
else
    echo "✅ 'lospos' kullanıcısı zaten var."
    # Şifreyi garantiye al (opsiyonel)
    if [ -n "$LOSPOS_PASSWORD" ]; then
        psql postgres -c "ALTER USER lospos WITH PASSWORD '$LOSPOS_PASSWORD';"
    fi
fi

# 'lospossettings' veritabanını oluştur (Eğer yoksa)
if ! psql -lqt | cut -d \| -f 1 | grep -qw lospossettings; then
    echo "📂 'lospossettings' veritabanı oluşturuluyor..."
    createdb -O lospos lospossettings
else
    echo "✅ 'lospossettings' veritabanı zaten var."
fi

# 4. Yetkilendirme
# 'pateez' (admin connection) için de yetki verelim ki uygulama ilk kurulumu yapabilsin
psql postgres -c "ALTER USER \"$CURRENT_USER\" WITH CREATEDB CREATEROLE;" || true

echo "🎉 İŞLEM TAMAMLANDI! PostgreSQL 18 artık aktif ve proje için hazır."
echo "✅ Eski sürüm kaldırıldı."
echo "✅ Yeni sürüm (boş) başlatıldı."
echo "✅ 'lospos' kullanıcısı ve DB ayarlandı."

echo ""
echo "⚠️ PostgreSQL 18 UPGRADE NOTU (pg_trgm / FTS / collation)"
echo "Bu script 'temiz kurulum' yapar (eski data taşınmaz). Eğer mevcut cluster'ı pg_upgrade ile yükseltiyorsan:"
echo "- Default collation provider libc değilse (ICU/builtin) PG18'de FTS+pg_trgm indeksleri REINDEX gerekebilir."
echo "- OS/ICU upgrade sonrası collation version mismatch uyarısı görürsen REINDEX + REFRESH COLLATION VERSION uygula."
echo ""
echo "Örnek (db owner/superuser):"
echo "  psql -d <db> -c \"REINDEX (VERBOSE) DATABASE \\\"<db>\\\";\""
echo "  psql -d <db> -c \"ALTER DATABASE \\\"<db>\\\" REFRESH COLLATION VERSION;\""
