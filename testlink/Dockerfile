# TestLink 1.9.20 on PHP 7.4 + Apache (stable combo for TestLink)
FROM php:7.4-apache

# Use Bash for robust RUN steps
SHELL ["/bin/bash", "-lc"]

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System deps + MySQL client
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    libonig-dev libicu-dev libcurl4-openssl-dev \
    default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions that TestLink needs
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd mysqli zip mbstring xml curl intl \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
 && docker-php-ext-install -j"$(nproc)" ldap

# Apache config: rewrite + DirectoryIndex + logs to stdout/stderr
RUN a2enmod rewrite && \
    printf '%s\n' 'ServerName localhost' > /etc/apache2/conf-available/servername.conf && \
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

# Fetch & install TestLink
RUN set -euo pipefail \
 && curl -fL --retry 5 -A "curl/7.x" \
      -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%201.9.20/testlink-1.9.20.tar.gz" \
 && mkdir -p /tmp/tl && tar -xzf /tmp/testlink.tar.gz -C /tmp/tl && rm /tmp/testlink.tar.gz \
 && TLROOT="$(find /tmp/tl -mindepth 1 -maxdepth 2 -type d -name 'testlink-*' -o -type d -name 'htdocs' | head -n1)" \
 && if [[ -d "$TLROOT/htdocs" ]]; then \
        cp -a "$TLROOT/htdocs/." /var/www/html/; \
    elif [[ -f "$TLROOT/index.php" ]]; then \
        cp -a "$TLROOT/." /var/www/html/; \
    else \
        echo "ERROR: TestLink archive layout unexpected"; ls -la "$TLROOT"; exit 1; \
    fi \
 && rm -rf /tmp/tl \
 && mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c \
 && chown -R www-data:www-data /var/www/html

# Our entrypoint will wire DB + schema + admin automatically
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
