# TestLink 1.9.20 on PHP 7.4 + Apache
FROM php:7.4-apache

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System & build deps for PHP extensions:
# - libonig-dev   -> mbstring (oniguruma)
# - libicu-dev    -> intl
# - libcurl4-openssl-dev -> curl
# - libxml2-dev   -> xml / pecl xmlrpc
# - libzip-dev    -> zip
# - libldap2-dev  -> ldap
# - libjpeg/freetype/png -> gd
# - $PHPIZE_DEPS  -> build toolchain for pecl/compiles
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    libonig-dev libicu-dev libcurl4-openssl-dev \
    $PHPIZE_DEPS \
 && rm -rf /var/lib/apt/lists/*

# Core PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd mysqli zip \
 && docker-php-ext-install -j"$(nproc)" mbstring xml curl intl \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
 && docker-php-ext-install -j"$(nproc)" ldap

# xmlrpc (moved to PECL for PHP 7.4)
# Use non-interactive install; enable after build
RUN yes "" | pecl install xmlrpc-1.0.0RC3 \
 && docker-php-ext-enable xmlrpc

# Apache tweaks
RUN a2enmod rewrite

# Fetch & install TestLink
RUN curl -L -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
 && tar -xzf /tmp/testlink.tar.gz -C /var/www/html --strip-components=1 \
 && rm /tmp/testlink.tar.gz \
 && chown -R www-data:www-data /var/www/html

# Entrypoint to prepare config_db.inc.php + API + admin
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
