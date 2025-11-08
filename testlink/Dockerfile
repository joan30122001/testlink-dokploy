# TestLink 1.9.20 on PHP 7.4 + Apache (known-good combo)
FROM php:7.4-apache
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System deps + mysql client
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    libonig-dev libicu-dev libcurl4-openssl-dev \
    default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions needed by TestLink
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd mysqli zip mbstring xml curl intl \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
 && docker-php-ext-install -j"$(nproc)" ldap

# Apache setup
RUN a2enmod rewrite && \
    printf '%s\n' 'ServerName localhost' > /etc/apache2/conf-available/servername.conf && a2enconf servername && \
    printf '%s\n' \
      '<Directory /var/www/html>' \
      '  Options FollowSymLinks' \
      '  AllowOverride All' \
      '  Require all granted' \
      '</Directory>' \
      'DirectoryIndex login.php index.php index.html' \
      > /etc/apache2/conf-available/testlink.conf && \
    a2enconf testlink && \
    ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/2 /var/log/apache2/error.log

# Fetch & install TestLink robustly
RUN set -euo pipefail \
 && curl -fL --retry 5 -A "curl/7.x" \
      -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%201.9.20/testlink-1.9.20.tar.gz" \
 && file /tmp/testlink.tar.gz | grep -qi 'gzip compressed data' \
 && mkdir -p /tmp/testlink \
 && tar -xzf /tmp/testlink.tar.gz -C /tmp/testlink \
 && rm /tmp/testlink.tar.gz \
 && TLROOT="$(find /tmp/testlink -mindepth 1 -maxdepth 1 -type d | head -n1)" \
 && if [ -d "${TLROOT}/htdocs" ]; then \
        shopt -s dotglob nullglob; mv "${TLROOT}/htdocs"/* /var/www/html/; \
    elif [ -f "${TLROOT}/index.php" ]; then \
        shopt -s dotglob nullglob; mv "${TLROOT}"/* /var/www/html/; \
    else \
        echo "ERROR: TestLink archive layout unexpected" >&2; ls -la "${TLROOT}"; exit 1; \
    fi \
 && if [ -f /var/www/html/config.inc.php.sample ] && [ ! -f /var/www/html/config.inc.php ]; then \
        cp /var/www/html/config.inc.php.sample /var/www/html/config.inc.php; \
    fi \
 && mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c \
 && chown -R www-data:www-data /var/www/html \
 && rm -rf /tmp/testlink

# Add entrypoint (writes DB config and imports schema if needed)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
