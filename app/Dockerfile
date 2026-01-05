FROM php:8.2-fpm-alpine

# Установка системных зависимостей и build-инструментов
RUN apk add --no-cache \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    libxml2-dev \
    postgresql-dev \
    bash \
    curl \
    # Build tools для компиляции расширений
    autoconf \
    g++ \
    make \
    # Для Redis
    pkgconfig \
    && rm -rf /var/cache/apk/*

# Установка основных PHP расширений
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo \
        pdo_mysql \
        mysqli \
        zip \
        intl \
        opcache \
        bcmath \
        soap \
        exif \
        pcntl

# Установка Redis расширения (используем последнюю стабильную версию)
RUN pecl channel-update pecl.php.net \
    && pecl install redis \
    && docker-php-ext-enable redis

# Очистка build-инструментов для уменьшения размера образа
RUN apk del autoconf g++ make pkgconfig

# Оптимизированная настройка OPcache
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.memory_consumption=512'; \
        echo 'opcache.interned_strings_buffer=64'; \
        echo 'opcache.max_accelerated_files=20000'; \
        echo 'opcache.revalidate_freq=0'; \
        echo 'opcache.validate_timestamps=0'; \
        echo 'opcache.fast_shutdown=1'; \
        echo 'opcache.enable_cli=0'; \
        echo 'opcache.save_comments=0'; \
        echo 'opcache.max_wasted_percentage=10'; \
        echo 'opcache.optimization_level=0x7FFFBFFF'; \
    } > /usr/local/etc/php/conf.d/opcache-optimized.ini

# Оптимизированная настройка PHP
RUN { \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}'; \
        echo 'post_max_size=${PHP_POST_MAX_SIZE}'; \
        echo 'date.timezone=UTC'; \
        echo 'realpath_cache_size=4M'; \
        echo 'realpath_cache_ttl=3600'; \
        echo 'max_input_vars=10000'; \
        echo 'expose_php=Off'; \
    } > /usr/local/etc/php/conf.d/performance.ini

# Настройка сессий для Redis
RUN { \
        echo 'session.save_handler = redis'; \
        echo 'session.save_path = "tcp://redis:6379"'; \
        echo 'session.gc_maxlifetime = 3600'; \
        echo 'session.cookie_lifetime = 0'; \
    } > /usr/local/etc/php/conf.d/session-redis.ini

# Создание директорий
RUN mkdir -p /var/www/html /var/lib/php/sessions \
    && chown -R www-data:www-data /var/www/html /var/lib/php/sessions

WORKDIR /var/www/html
USER www-data
EXPOSE 9000
CMD ["php-fpm"]

