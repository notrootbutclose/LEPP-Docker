FROM php:8.2-fpm-alpine

# Установка зависимостей и компиляция расширений в один слой
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libzip-dev \
        icu-dev \
        postgresql-dev \
    && apk add --no-cache \
        freetype \
        libjpeg-turbo \
        libpng \
        libzip \
        icu-libs \
        postgresql-libs \
    # Конфигурация GD
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    # Компиляция расширений
    && docker-php-ext-install -j$(nproc) \
        gd \
        pdo_pgsql \
        pgsql \
        zip \
        intl \
        opcache \
        bcmath \
    # Установка Redis
    && pecl install redis \
    && docker-php-ext-enable redis \
    # Очистка
    && apk del .build-deps \
    && rm -rf /tmp/pear

# PHP конфигурация
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'session.save_handler=redis'; \
    echo 'session.save_path="tcp://redis:6379"'; \
    echo 'expose_php=Off'; \
    } > /usr/local/etc/php/conf.d/custom.ini

# Создание директорий
RUN mkdir -p /var/www/html /var/lib/php/sessions && \
    chown -R www-data:www-data /var/www/html /var/lib/php/sessions

USER www-data
WORKDIR /var/www/html
EXPOSE 9000

CMD ["php-fpm"]
