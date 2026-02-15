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
# Not: Eğer postgresql@18 henüz tap'lerde yoksa, en güncel sürümü (postgresql@17 veya head) dener.
# PG18 resmi olarak yayınlanmadıysa @head kullanılır.
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
