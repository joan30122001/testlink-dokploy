# TestLink 1.9.20 on PHP 7.4 + Apache (stable combo for TestLink)
FROM php:7.4-apache

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System deps for PHP extensions + mysql client for healthcheck/debug
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git \
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

# Apache: enable rewrite, allow .htaccess, set DirectoryIndex (include login.php)
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

# # Fetch & unpack TestLink
# RUN curl -L -o /tmp/testlink.tar.gz \
#       "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
#  && tar -xzf /tmp/testlink.tar.gz -C /var/www/html --strip-components=1 \
#  && rm /tmp/testlink.tar.gz

# Fetch & install TestLink (robust)
RUN set -euo pipefail \
 && curl -fL --retry 5 -A "curl/7.x" \
      -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
 # sanity check that we didn't get an HTML error page
 && file /tmp/testlink.tar.gz | grep -qi 'gzip compressed data' \
 && mkdir -p /tmp/testlink \
 && tar -xzf /tmp/testlink.tar.gz -C /tmp/testlink \
 && rm /tmp/testlink.tar.gz \
 # detect the real extracted top dir
 && TLROOT="$(find /tmp/testlink -mindepth 1 -maxdepth 1 -type d | head -n1)" \
 # Case A: legacy layout has /htdocs
 && if [ -d "${TLROOT}/htdocs" ]; then \
        shopt -s dotglob nullglob; mv "${TLROOT}/htdocs"/* /var/www/html/; \
    # Case B: files already at top-level (index.php, gui/, lib/, etc.)
    elif [ -f "${TLROOT}/index.php" ]; then \
        shopt -s dotglob nullglob; mv "${TLROOT}"/* /var/www/html/; \
    else \
        echo "ERROR: Could not find htdocs/ or index.php in extracted archive" >&2; \
        ls -la "${TLROOT}"; \
        exit 1; \
    fi \
 # Ensure config present if sample exists
 && if [ -f /var/www/html/config.inc.php.sample ] && [ ! -f /var/www/html/config.inc.php ]; then \
        cp /var/www/html/config.inc.php.sample /var/www/html/config.inc.php; \
    fi \
 # Ownership
 && chown -R www-data:www-data /var/www/html \
 && rm -rf /tmp/testlink

# # Make writable dirs (needed by installer & runtime)
# RUN mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c && \
#     chown -R www-data:www-data /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
