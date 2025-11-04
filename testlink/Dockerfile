# TestLink 1.9.20 on PHP 7.4 + Apache
FROM php:7.4-apache

ENV DEBIAN_FRONTEND=noninteractive \
    TL_VERSION=1.9.20 \
    TZ=UTC
WORKDIR /var/www/html

# ---- Runtime deps (kept) + build deps (removed later) ----
# Notes:
# - libonig-dev -> mbstring
# - libicu-dev  -> intl
# - libcurl4-openssl-dev -> curl
# - libxml2-dev -> xml / pecl xmlrpc
# - libzip-dev  -> zip
# - libldap2-dev -> ldap
# - libjpeg/freetype/png -> gd
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git tzdata \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    libonig-dev libicu-dev libcurl4-openssl-dev \
 && rm -rf /var/lib/apt/lists/*

# Build toolchain (temporary) for PECL ext
RUN apt-get update && apt-get install -y --no-install-recommends $PHPIZE_DEPS \
 && rm -rf /var/lib/apt/lists/*

# ---- PHP extensions ----
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd mysqli zip \
 && docker-php-ext-install -j"$(nproc)" mbstring xml curl intl \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
 && docker-php-ext-install -j"$(nproc)" ldap

# xmlrpc for PHP 7.4
RUN yes "" | pecl install xmlrpc-1.0.0RC3 \
 && docker-php-ext-enable xmlrpc

# ---- Apache & PHP tweaks ----
RUN a2enmod rewrite \
 && { \
      echo 'date.timezone=${TZ}'; \
      echo 'upload_max_filesize=64M'; \
      echo 'post_max_size=64M'; \
      echo 'memory_limit=512M'; \
      echo 'max_execution_time=300'; \
    } > /usr/local/etc/php/conf.d/testlink.ini \
 # Allow .htaccess (TestLink relies on it in some setups)
 && printf '%s\n' \
    '<Directory /var/www/html>' \
    '    AllowOverride All' \
    '</Directory>' \
    > /etc/apache2/conf-available/allow-override.conf \
 && a2enconf allow-override

# ---- Fetch & install TestLink ----
RUN curl -fsSL -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
 && tar -xzf /tmp/testlink.tar.gz -C /var/www/html --strip-components=1 \
 && rm -f /tmp/testlink.tar.gz \
 && mkdir -p /var/www/html/{logs,upload_area} \
 && chown -R www-data:www-data /var/www/html

# Useful persistence points (optional but recommended)
VOLUME ["/var/www/html/logs", "/var/www/html/upload_area"]

# ---- Entrypoint ----
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=5 \
  CMD curl -fsS http://localhost/ || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
