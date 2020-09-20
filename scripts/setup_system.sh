#!/bin/sh
# enable ssh as root
HOSTNAME=mobian

# set hostname
echo $HOSTNAME > /etc/hostname
{
	echo '127.0.0.1	localhost mobian'
        echo ' '
        echo '# The following lines are desirable for IPv6 capable hosts'
        echo '::1	localhost ip6-localhost ip6-loopback'
        echo 'ff02::1	ip6-allnodes'
        echo 'ff02::2	ip6-allrouters'
} > /etc/hosts

# Generate locales (only en_US.UTF-8 for now)
sed -i -e '/en_US\.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

