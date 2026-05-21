#!/bin/sh
set -e
 
cd /var/www/html
 
echo "⏳ Waiting for MySQL..."
until php artisan db:show --quiet 2>/dev/null; do
  sleep 2
done
echo "✅ MySQL ready."
 
# Cache config & routes untuk production
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache
 
# Jalankan migration
php artisan migrate --force
 
echo "🚀 Starting application..."
exec "$@"