# TestLink 1.9.20 on PHP 7.4 + Apache
FROM php:7.4-apache

# Use bash for a couple of shell conveniences in RUN lines
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System deps + mysql client (handy for debugging)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git file \
      libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
      libzip-dev libldap2-dev libxml2-dev \
      libonig-dev libicu-dev libcurl4-openssl-dev \
      default-mysql-client \
  && rm -rf /var/lib/apt/lists/*

# PHP extensions required by TestLink
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install -j"$(nproc)" gd mysqli zip mbstring xml curl intl \
  && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
  && docker-php-ext-install -j"$(nproc)" ldap

# Apache: enable rewrite + basic conf
RUN a2enmod rewrite && \
    printf '%s\n' \
      'ServerName localhost' \
      > /etc/apache2/conf-available/servername.conf && \
    a2enconf servername && \
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

# Fetch & install TestLink robustly (handles archive layouts)
RUN set -euo pipefail \
 && curl -fL --retry 5 -A "curl/7.x" \
      -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
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
        echo "ERROR: TestLink archive layout unexpected"; ls -la "${TLROOT}"; exit 1; \
    fi \
 # If the sample exists and main config doesn't, copy it (installer can update later)
 && if [ -f /var/www/html/config.inc.php.sample ] && [ ! -f /var/www/html/config.inc.php ]; then \
        cp /var/www/html/config.inc.php.sample /var/www/html/config.inc.php; \
    fi \
 # Writable dirs needed by TestLink
 && mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c \
 && chown -R www-data:www-data /var/www/html \
 && rm -rf /tmp/testlink

# Create installer-expected absolute paths and link them to the app dirs
RUN mkdir -p /var/testlink/logs /var/testlink/upload_area \
 && chown -R www-data:www-data /var/testlink \
 && rm -rf /var/www/html/logs /var/www/html/upload_area || true \
 && ln -s /var/testlink/logs /var/www/html/logs \
 && ln -s /var/testlink/upload_area /var/www/html/upload_area

# ✅ Force "/" to go to /login.php so reverse proxies don't 404
RUN printf '%s\n' \
  'RewriteEngine On' \
  'DirectoryIndex login.php index.php index.html' \
  'RewriteCond %{REQUEST_URI} ^/$' \
  'RewriteRule ^$ login.php [L,R=302]' \
  > /var/www/html/.htaccess

EXPOSE 80
CMD ["apache2-foreground"]
