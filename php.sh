#!/usr/bin/env bash
#
# Follow up commands are best suitable for clean Ubuntu 16.04 installation
# All commands are executed by the root user
# Nginx library is installed from custom ppa/ repository
# https://launchpad.net/~hda-me/+archive/ubuntu/nginx-stable
# This will not be available for any other OS rather then Ubuntu
#
# Disable external access to PHP-FPM scripts
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.3/fpm/php.ini
# Switch to the ondemand state of PHP-FPM
sed -i "s/^pm = .*/pm = ondemand/" /etc/php/7.3/fpm/pool.d/www.conf
# Use such number of children that will not hurt other parts of the system
# Let's assume that system itself needs 128 MB of RAM
# Let's assume that we let have MariaDB another 256 MB to run
# And finally let's assume that Nginx will need something like 8 MB to run
# On the 1 GB system that leads up to 632 MB of free memory
# If we give one PHP-FPM child a moderate amount of RAM for example 32 MB that will let us create 19 PHP-FPM proccesses at max
# Check median of how much PHP-FPM child consumes with the following command
# ps --no-headers -o "rss,cmd" -C php-fpm7.3 | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"M") }'
ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
free=$(((ram/1024)-128-256-8))
php=$(((free/32)))
children=$(printf %.0f $php)
sed -i "s/^pm.max_children = .*/pm.max_children = $children/" /etc/php/7.3/fpm/pool.d/www.conf
# Comment default dynamic mode settings and make them more adequate
sed -i "s/^pm.start_servers = .*/;pm.start_servers = 5/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/^pm.min_spare_servers = .*/;pm.min_spare_servers = 2/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/^pm.max_spare_servers = .*/;pm.max_spare_servers = 2/" /etc/php/7.3/fpm/pool.d/www.conf
# State what amount of request one PHP-FPM child can sustain
sed -i "s/^;pm.max_requests = .*/pm.max_requests = 400/" /etc/php/7.3/fpm/pool.d/www.conf
# State after what amount of time unused PHP-FPM children will stop
sed -i "s/^;pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s;/" /etc/php/7.3/fpm/pool.d/www.conf
# Create a /status path for your webserver in order to track current requests to it
# Use IP/status to check PHP-FPM stats or IP/status?full&html for more detailed results
sed -i "s/^;pm.status_path = \/status/pm.status_path = \/status/" /etc/php/7.3/fpm/pool.d/www.conf
# Create a /ping path for your PHP-FPM installation in order to be able to make heartbeat calls to it
sed -i "s/^;ping.path = \/ping/ping.path = \/ping/" /etc/php/7.3/fpm/pool.d/www.conf
# Enable PHP-FPM Opcache
sed -i "s/^;opcache.enable=0/opcache.enable=1/" /etc/php/7.3/fpm/php.ini
# Set maximum memory limit for OPcache
sed -i "s/^;opcache.memory_consumption=64/opcache.memory_consumption=64/" /etc/php/7.3/fpm/php.ini
# Raise the maximum limit of variable that can be stored in OPcache
sed -i "s/^;opcache.interned_strings_buffer=4/opcache.interned_strings_buffer=16/" /etc/php/7.3/fpm/php.ini
# Set maximum amount fo files to be cached in OPcache
sed -i "s/^;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=65536/" /etc/php/7.3/fpm/php.ini
# Enabled using directory path in order to avoid collision between two files with identical names in OPcache
sed -i "s/^;opcache.use_cwd=1/opcache.use_cwd=1/" /etc/php/7.3/fpm/php.ini
# Enable validation of changes in php files
sed -i "s/^;opcache.validate_timestamps=1/opcache.validate_timestamps=1/" /etc/php/7.3/fpm/php.ini
# Set validation period in seconds for OPcache file
sed -i "s/^;opcache.revalidate_freq=2/opcache.revalidate_freq=2/" /etc/php/7.3/fpm/php.ini
# Disable comments to be put in OPcache code
sed -i "s/^;opcache.save_comments=1/opcache.save_comments=0/" /etc/php/7.3/fpm/php.ini
# Enable fast shutdown
sed -i "s/^;opcache.fast_shutdown=0/opcache.fast_shutdown=1/" /etc/php/7.3/fpm/php.ini
# Set period in seconds in which PHP-FPM should restart if OPcache is not accessible
sed -i "s/^;opcache.force_restart_timeout=180/opcache.force_restart_timeout=30/" /etc/php/7.3/fpm/php.ini
# Reload Nginx installation
/etc/init.d/nginx reload 
# Reload PHP-FPM installation
/etc/init.d/php7.3-fpm reload

# Create a Monit configuration file to watch after PHP-FPM
# Monit will check the availability of php7.3-fpm.sock
# And restart php7.3-fpm service if it can't be accessible
# If Monit tries to many times to restart it withour success it will take a timeout and then proceed to restart again
echo -e 'check process php7.3-fpm with pidfile /var/run/php/php7.3-fpm.pid\nstart program = "/etc/init.d/php7.3-fpm start"\nstop program = "/etc/init.d/php7.3-fpm stop"\nif failed unixsocket /run/php/php7.3-fpm.sock then restart\nif 5 restarts within 5 cycles then timeout' > /etc/monit/conf.d/php7.3-fpm.conf
