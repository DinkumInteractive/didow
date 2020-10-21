# Adds xDebug support to Wordpress
# Docker Hub: https://registry.hub.docker.com/u/johnrom/docker-wordpress-wp-cli-xdebug/
# Github Repo: https://github.com/johnrom/docker-wordpress-wp-cli-xdebug

FROM wordpress:5.5.1-php7.4-apache
LABEL maintainer=guillermo@dinkuminteractive.com

# Add sudo in order to run wp-cli as the www-data user
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && apt-get install -y sudo less subversion && apt-get -q -y install mariadb-client

# Add WP-CLI
RUN curl -o /bin/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
COPY wp-su.sh /bin/wp
RUN chmod +x /bin/wp-cli.phar /bin/wp

# Add PHP unit test
RUN curl -Lo /tmp/phpunit.phar https://phar.phpunit.de/phpunit-6.0.phar \
    && chmod +x /tmp/phpunit.phar \
    && sudo mv /tmp/phpunit.phar /bin/phpunit

# Add xDebug
RUN yes | pecl install xdebug \
	&& docker-php-ext-enable xdebug

# Add apcu
RUN yes | pecl install apcu \
	&& docker-php-ext-enable apcu

# Cleanup
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
