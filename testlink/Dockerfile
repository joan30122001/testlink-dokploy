# TestLink 1.9.20 on PHP 7.4 + Apache
FROM php:7.4-apache

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

# System deps for PHP extensions + mysql client used by entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip git \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    libonig-dev libicu-dev libcurl4-openssl-dev \
    $PHPIZE_DEPS \
    default-mysql-client \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" gd mysqli zip mbstring xml curl intl \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu \
 && docker-php-ext-install -j"$(nproc)" ldap

# Apache: rewrite + allow serving docroot + .htaccess, stream logs
RUN a2enmod rewrite && \
    printf '%s\n' \
      '<Directory /var/www/html>' \
      '  Options FollowSymLinks' \
      '  AllowOverride All' \
      '  Require all granted' \
      '</Directory>' \
      'DirectoryIndex index.php index.html' \
      > /etc/apache2/conf-available/testlink.conf && \
    a2enconf testlink && \
    ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/2 /var/log/apache2/error.log

# Fetch & install TestLink
RUN curl -L -o /tmp/testlink.tar.gz \
      "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
 && tar -xzf /tmp/testlink.tar.gz -C /var/www/html --strip-components=1 \
 && rm /tmp/testlink.tar.gz \
 && chown -R www-data:www-data /var/www/html

# Entrypoint to prepare config_db.inc.php + API + admin bootstrap
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
