FROM ubuntu:22.04

# START BASE --------------------------------------------------------

# install base soft for allow apt-add-repository
## Disable interactive install
RUN export DEBIAN_FRONTEND="noninteractive" \
    && apt-get update -qq \
    && apt-get -qqy install software-properties-common apt-utils locales tzdata \
    && apt-get install -y --no-install-recommends libzip-dev unzip procps inotify-tools

# set UTC timezone
RUN echo "UTC" > /etc/timezone \
    && rm -f /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && date

# install git
RUN apt-get install -y git zip unzip

RUN apt-get -qqy install build-essential libssl1.0-dev git curl wget libfontconfig1 libxrender1 ghostscript fontconfig nano htop supervisor cron

RUN apt-add-repository ppa:ondrej/php

# install requirements (php)
RUN apt-get install -qqy memcached php7.4 php7.4-dom php7.4-fpm php7.4-bcmath php7.4-memcached php7.4-xml php7.4-mbstring php7.4-gd php7.4-pdo php7.4-mysql php7.4-imagick php7.4-common php7.4-zip php7.4-curl libsqlite3-dev mysql-client openssh-server php7.4-cli php7.4-sqlite php7.4-sqlite3

RUN apt-get update -qq \
    && apt-get -y clean > /dev/null \
    && rm -rf /var/www/* && rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer \
    && composer clear-cache \
    && composer global require hirak/prestissimo

RUN rm -rf /srv/www/* && mkdir /srv/www \
    # Clean up
    && apt-get -y clean > /dev/null \
    && rm -rf /var/www/* && rm -rf /var/lib/apt/lists/* \
    # Start service once so that it properly initializes
    && service php7.4-fpm start && service php7.4-fpm stop

# END BASE --------------------------------------------------------

WORKDIR /srv/www

RUN rm -rf vendor \
    && rm -rf var/cache/* \
    && rm -rf var/log/* \
    && rm -rf var/sessions/*

COPY . /srv/www

# cron configure
COPY .docker/etc/cron.d/base /etc/cron.d/

# php configure
COPY .docker/etc/php/php.ini /etc/php/7.4/fpm/conf.d/50-dev.ini
COPY .docker/etc/php/php-cli.ini /etc/php/7.4/cli/conf.d/60-dev.ini
COPY .docker/etc/php/php-fpm-pool.conf /etc/php/7.4/fpm/pool.d/www.conf

RUN cd /srv/www \
    && composer install -q \
    && composer dump-autoload --optimize \
    && bin/console cache:clear \
    && bin/console cache:warmup

# set permissions
RUN chmod +x /srv/www/bin/* \
    && chown www-data:www-data /srv/www \
    && chown www-data:www-data /srv/www/var -R \
    && chown www-data:www-data /srv/www/public -R \
    && chmod 644 /etc/cron.d/*

RUN apt-get update \
    && apt-get install -qqy php7.4-xdebug

# Download RoadRunner `spiral/roadrunner` && `symfony/psr-http-message-bridge`
ENV RR_VERSION 1.4.7
RUN mkdir /tmp/rr \
  && cd /tmp/rr \
  && echo "{\"require\":{\"spiral/roadrunner\":\"${RR_VERSION}\"}}" >> composer.json \
  && composer install \
  && vendor/bin/rr get-binary -l /usr/local/bin \
  && rm -rf /tmp/rr

EXPOSE 80

CMD ["/usr/local/bin/rr", "serve", "-d", "-c", "/etc/roadrunner/.rr.yaml"]
