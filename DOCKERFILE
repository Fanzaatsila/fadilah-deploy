
# ─────────────────────────────────────────────
# Stage 1: Node – build Vite assets
# ─────────────────────────────────────────────
FROM node:20-alpine AS node-builder
 
WORKDIR /app
 
COPY package*.json ./
RUN npm ci --ignore-scripts
 
COPY . .
RUN npm run build
 
# ─────────────────────────────────────────────
# Stage 2: Composer – install PHP dependencies
# ─────────────────────────────────────────────
FROM composer:2.8 AS composer-builder
 
WORKDIR /app
 
COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-plugins \
    --no-scripts \
    --optimize-autoloader \
    --prefer-dist
 
COPY . .
RUN composer dump-autoload --optimize
 
# ─────────────────────────────────────────────
# Stage 3: Final image – PHP 8.3 FPM + Nginx
# ─────────────────────────────────────────────
FROM php:8.3-fpm-alpine
 
LABEL maintainer="your-email@example.com"
 
# ── System dependencies ──────────────────────
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libzip-dev \
    oniguruma-dev \
    icu-dev \
    linux-headers \
    $PHPIZE_DEPS
 
# ── PHP extensions ───────────────────────────
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        gd \
        zip \
        intl \
        opcache
 
# ── Redis extension (optional, hapus jika tidak dipakai) ──
RUN pecl install redis && docker-php-ext-enable redis
 
# ── Nginx config ─────────────────────────────
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf
 
# ── PHP-FPM config ───────────────────────────
COPY docker/php/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/www.conf
 
# ── Supervisor config ────────────────────────
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
 
# ── App files ────────────────────────────────
WORKDIR /var/www/html
 
COPY --from=composer-builder /app /var/www/html
COPY --from=node-builder /app/public/build /var/www/html/public/build
 
# ── Permissions ──────────────────────────────
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache
 
# ── Entrypoint ───────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
 
EXPOSE 80
 
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]