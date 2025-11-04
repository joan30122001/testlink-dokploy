FROM php:7.4-apache

ENV TL_VERSION=1.9.20
WORKDIR /var/www/html

RUN apt-get update && apt-get install -y \
    curl unzip git ca-certificates \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libldap2-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mysqli zip

# xmlrpc (PHP 7.4) via PECL
RUN pecl install xmlrpc-1.0.0RC3 && docker-php-ext-enable xmlrpc

RUN a2enmod rewrite

# Téléchargement TestLink
RUN curl -L -o /tmp/testlink.tar.gz \
    "https://downloads.sourceforge.net/project/testlink/TestLink%201.9/TestLink%20${TL_VERSION}/testlink-${TL_VERSION}.tar.gz" \
 && tar -xzf /tmp/testlink.tar.gz -C /var/www/html --strip-components=1 \
 && rm /tmp/testlink.tar.gz \
 && chown -R www-data:www-data /var/www/html

# Entrypoint qui prépare config_db.inc.php + API + admin
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
