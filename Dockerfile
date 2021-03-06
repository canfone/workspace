FROM phusion/baseimage:latest

MAINTAINER Cliff Richard Anfone <anfone.cliff@gmail.com>

RUN DEBIAN_FRONTEND=noninteractive
RUN locale-gen en_US.UTF-8

ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LC_CTYPE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV TERM xterm

RUN apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:ondrej/php

RUN apt-get update && \
    apt-get install -y --allow-downgrades --allow-remove-essential \
        --allow-change-held-packages \
        php7.3-cli \
        php7.3-common \
        php7.3-curl \
        php7.3-intl \
        php7.3-json \
        php7.3-xml \
        php7.3-mbstring \
        php7.3-mysqli \
        php7.3-pgsql \
        php7.3-sqlite \
        php7.3-sqlite3 \
        php7.3-zip \
        php7.3-bcmath \
        php7.3-memcached \
        php7.3-gd \
        php7.3-dev \
        pkg-config \
        libcurl4-openssl-dev \
        libedit-dev \
        libssl-dev \
        libxml2-dev \
        xz-utils \
        libsqlite3-dev \
        sqlite3 \
        git \
        curl \
        vim \
        nano \
        postgresql-client \
        zlib1g-dev \
        bzip2 \
        libbz2-dev \
        unzip \
    && apt-get clean

RUN curl -s http://getcomposer.org/installer | php && \
    echo "export PATH=${PATH}:/var/www/vendor/bin" >> ~/.bashrc && \
    mv composer.phar /usr/local/bin/composer

RUN . ~/.bashrc


# Devuser

ARG PUID=1000
ARG PGID=1000

ENV PUID ${PUID}
ENV PGID ${PGID}

RUN apt-get update -yqq && \
    pecl channel-update pecl.php.net && \
    groupadd -g ${PGID} devuser && \
    useradd -u ${PUID} -g devuser -m devuser -G docker_env && \
    usermod -p "*" devuser


# Set Timezone

ARG TZ=UTC
ENV TZ ${TZ}
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# User Aliases

USER root

COPY ./aliases.sh /root/aliases.sh
COPY ./aliases.sh /home/devuser/aliases.sh

RUN sed -i 's/\r//' /root/aliases.sh && \
    sed -i 's/\r//' /home/devuser/aliases.sh && \
    chown devuser:devuser /home/devuser/aliases.sh && \
    echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc

USER devuser

RUN echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc



# Composer

USER root

COPY ./composer.json /home/devuser/.composer/composer.json
RUN chown -R devuser:devuser /home/devuser/.composer


USER devuser

RUN echo "" >> ~/.bashrc && \
    echo 'export PATH="~/.composer/vendor/bin:$PATH"' >> ~/.bashrc


# PHPUnit

RUN echo "" >> ~/.bashrc && \
    echo 'export PATH="/var/www/vendor/bin:$PATH"' >> ~/.bashrc


# Crontab

USER root


COPY ./crontab /etc/cron.d
RUN chmod -R 644 /etc/cron.d


# XDebug

RUN apt-get update && \
    apt-get install -y --force-yes php7.3-xdebug && \
    sed -i 's/^;//g' /etc/php/7.3/cli/conf.d/20-xdebug.ini && \
    echo "alias phpunit='php -dzend_extension=xdebug.so /var/www/vendor/bin/phpunit'" >> ~/.bashrc

COPY ./xdebug.ini /etc/php/7.3/cli/conf.d/xdebug.ini

RUN sed -i "s/xdebug.remote_autostart=0/xdebug.remote_autostart=1/" /etc/php/7.3/cli/conf.d/xdebug.ini && \
    sed -i "s/xdebug.remote_enable=0/xdebug.remote_enable=1/" /etc/php/7.3/cli/conf.d/xdebug.ini && \
    sed -i "s/xdebug.cli_color=0/xdebug.cli_color=1/" /etc/php/7.3/cli/conf.d/xdebug.ini


USER devuser

ENV NVM_DIR /home/devuser/.nvm
ENV NPM_REGISTRY https://registry.npmjs.org

# Install nvm (A Node Version Manager)
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.8/install.sh | bash \
        && . $NVM_DIR/nvm.sh \
        && nvm install node \
        && nvm use node \
        && nvm alias node \
	&& npm config set registry ${NPM_REGISTRY} \
	&& npm install -g @vue/cli

RUN echo "" >> ~/.bashrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc


USER root

RUN echo "" >> ~/.bashrc && \
    echo 'export NVM_DIR="/home/devuser/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc

ENV PATH $PATH:$NVM_DIR/versions/node/vnode/bin

RUN . ~/.bashrc && npm config set registry ${NPM_REGISTRY} 

# Last

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /var/www
