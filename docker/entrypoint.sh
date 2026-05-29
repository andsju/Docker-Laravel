#!/bin/bash
set -e

# If APP_KEY is empty in the environment (e.g. not set in host .env),
# unset it so Laravel falls back to the key baked in during the Docker build.
if [ -z "$APP_KEY" ]; then
    unset APP_KEY
fi

# Ensure required storage directories exist (important when the host
# storage/ folder is freshly cloned and sub-directories are missing).
mkdir -p storage/framework/{cache/data,sessions,testing,views} \
         storage/logs \
         storage/app/{public,private}

# Fix permissions on directories that may be bind-mounted from the host.
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R 775 storage bootstrap/cache 2>/dev/null || true

echo "==> Waiting for database..."
until php -r "
    try {
        new PDO(
            'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT'),
            getenv('DB_USERNAME'),
            getenv('DB_PASSWORD')
        );
    } catch (Exception \$e) {
        exit(1);
    }
" 2>/dev/null; do
    echo "  Database not ready, retrying in 2 s..."
    sleep 2
done
echo "==> Database ready."

echo "==> Running migrations..."
php artisan migrate --force

echo "==> Linking public storage..."
php artisan storage:link --force

echo "==> Starting Apache..."
exec apache2-foreground
