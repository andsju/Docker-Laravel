FROM php:8.4-apache

# ── System dependencies ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
    git \
    curl \
    zip \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────────────
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip

# ── Apache: enable mod_rewrite and deploy a clean VirtualHost config ──────────
RUN a2enmod rewrite
COPY docker/apache.conf /etc/apache2/sites-available/000-default.conf

# ── PHP upload limits ─────────────────────────────────────────────────────────
COPY docker/php-uploads.ini /usr/local/etc/php/conf.d/uploads.ini

# ── Working directory ─────────────────────────────────────────────────────────
WORKDIR /var/www/html

# ── Composer ──────────────────────────────────────────────────────────────────
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# ── PHP dependencies (dedicated layer for build-cache efficiency) ─────────────
# vendor/ is installed here and never bind-mounted at runtime.
# This avoids the extreme slowness of mounting vendor/ on Windows/macOS hosts.
COPY composer.json composer.lock ./
RUN composer install --no-scripts --optimize-autoloader

# ── Application source ────────────────────────────────────────────────────────
COPY . .
RUN composer dump-autoload --optimize

# ── Build-time APP_KEY + package discovery ────────────────────────────────────
# A key is generated once at image build time so the app is immediately usable.
# At runtime the value can be overridden by setting APP_KEY in the host .env.
# The entrypoint handles the case where .env passes an empty APP_KEY.
# package:discover writes bootstrap/cache/packages.php so all service providers
# are registered correctly (skipped by --no-scripts in composer install above).
RUN cp .env.example .env \
    && php artisan key:generate \
    && php artisan package:discover --ansi

# ── Permissions ───────────────────────────────────────────────────────────────
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 storage bootstrap/cache \
    && chmod +x docker/entrypoint.sh

ENTRYPOINT ["/var/www/html/docker/entrypoint.sh"]
EXPOSE 80