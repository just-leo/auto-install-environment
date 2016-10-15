#!/bin/bash
# username="$USER"
username=user
# Variables
APPENV=local
DBHOST=localhost
DBUSER=root
DBPASSWD=root
DBNAME=CashFusionDb
BASEDIR=/home/${username}/CashFusion
echo -e "\n--- Creating working dirs... ---\n"
if [ ! -d "$BASEDIR" ]; then
    mkdir --mode=777 -v ${BASEDIR}
fi
if [ ! -d "$BASEDIR/web/" ]; then
    mkdir --mode=777 -v ${BASEDIR}/web/
fi
if [ ! -d "$BASEDIR/serial/" ]; then
    mkdir --mode=777 -v ${BASEDIR}/serial/
fi
chown ${username}:${username} ${BASEDIR} -R

echo -e "\n--- Installing now... ---\n"
echo -e "\n--- Updating packages list ---\n"
apt-get -qq update
echo -e "\n--- Install base packages ---\n"
apt-get -y install curl build-essential mc openssh-server git > /dev/null 2>&1
# echo -e "\n--- Add some repos to update our distro ---\n"
# add-apt-repository ppa:ondrej/php5 > /dev/null 2>&1
# add-apt-repository ppa:chris-lea/node.js > /dev/null 2>&1
echo -e "\n--- Install MySQL specific packages and settings ---\n"
echo "mysql-server mysql-server/root_password password $DBPASSWD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password $DBPASSWD" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect none" | debconf-set-selections
apt-get -y install mysql-server-5.6 phpmyadmin > /dev/null 2>&1
echo -e "\n--- Setting up our MySQL user and db ---\n"
mysql -uroot -p$DBPASSWD -e "CREATE DATABASE CashFusionDb"
mysql -uroot -p$DBPASSWD -e "CREATE DATABASE CommonDb"
mysql -uroot -p$DBPASSWD -e "grant all privileges on CashFusionDb.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "grant all privileges on CommonDb.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'"
echo -e "\n--- Installing PHP-specific packages ---\n"
apt-get -y install php5 apache2 libapache2-mod-php5 php5 php5-dev php5-intl php5-mcrypt php5-curl php5-mysql php-apc > /dev/null 2>&1
echo -e "\n--- Enabling mod-rewrite ---\n"
a2enmod rewrite > /dev/null 2>&1
php5enmod mcrypt > /dev/null 2>&1
# echo -e "\n--- Allowing Apache override to all ---\n"
# sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf
# echo -e "\n--- Setting document root to public directory ---\n"
# rm -rf /var/www
# ln -fs /vagrant/public /var/www
echo -e "\n--- Configure Apache to use phpmyadmin ---\n"
echo -e "\n\nListen 81\n" >> /etc/apache2/ports.conf
cat > /etc/apache2/conf-available/phpmyadmin.conf << "EOF"
<VirtualHost *:81>
    ServerAdmin webmaster@localhost
    DocumentRoot /usr/share/phpmyadmin
    DirectoryIndex index.php
    ErrorLog ${APACHE_LOG_DIR}/phpmyadmin-error.log
    CustomLog ${APACHE_LOG_DIR}/phpmyadmin-access.log combined
</VirtualHost>
EOF
a2enconf phpmyadmin > /dev/null 2>&1
echo -e "\n--- Add environment variables to Apache ---\n"
cat > /etc/apache2/sites-available/000-default.conf <<EOF
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot ${BASEDIR}/web/backend/web
    <Directory ${BASEDIR}/web/backend/web/>
		Options Indexes FollowSymLinks MultiViews
		AllowOverride All
		Order allow,deny
		Allow from All
		Require all granted
    </Directory>
</VirtualHost>
EOF
echo -e "\n--- Restarting Apache ---\n"
service apache2 restart > /dev/null 2>&1
echo -e "\n--- We definitly need to see the PHP errors, turning them on ---\n"
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
sed -i "s/memory_limit = .*/memory_limit = 256M/" /etc/php5/apache2/php.ini
sed -i "s/max_input_time = .*/max_input_time = 180/" /etc/php5/apache2/php.ini
sed -i "s/max_execution_time = .*/max_execution_time = 180/" /etc/php5/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 200M/" /etc/php5/apache2/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 200M/" /etc/php5/apache2/php.ini
# echo -e "\n--- Turn off disabled pcntl functions so we can use Boris ---\n"
# sed -i "s/disable_functions = .*//" /etc/php5/cli/php.ini
# TODO
# pear channel-discover pear.phing.info
# pear install phing/phing
echo -e "\n--- Installing Composer for PHP package management ---\n"
curl --silent https://getcomposer.org/installer | php > /dev/null 2>&1
mv composer.phar /usr/local/bin/composer

echo -e "\n--- Installing NodeJS and NPM ---\n"
wget https://nodejs.org/dist/v0.12.16/node-v0.12.16.tar.gz | tar -xf ./node-v0.12.16.tar.gz > /dev/null 2>&1
if [ -d "node-v0.12.16" ]; then
    chown ${username}:${username} node-v0.12.16 -R
    pushd node-v0.12.16
    ./configure > /dev/null 2>&1
    make > /dev/null 2>&1
    make install
    popd
    echo -e "\n--- Installing javascript components ---\n"
    chown -R ${username} $(npm config get prefix)/{lib/node_modules,bin,share}
    npm install -g gulp forever > /dev/null 2>&1
fi
# old way
# curl -sL https://deb.nodesource.com/setup_0.12 | sudo -E bash - > /dev/null 2>&1
# apt-get -y install nodejs > /dev/null 2>&1

echo -e "\n--- Updating project components and pulling latest versions ---\n"
# pushd ${BASEDIR}/serial/
# sudo -u $username -H sh -c "npm install" > /dev/null 2>&1
# sudo -u $username -H sh -c "gulp" > /dev/null 2>&1
# popd
chown ${username}:${username} /home/${username}/.composer
composer global require "fxp/composer-asset-plugin"
# Set envvars
# export APP_ENV=$APPENV
# export DB_HOST=$DBHOST
# export DB_NAME=$DBNAME
# export DB_USER=$DBUSER
# export DB_PASS=$DBPASSWD
echo -e "\n--- Please install manual: ubuntu-restricted-extras ubuntu-restricted-addons ---\n"