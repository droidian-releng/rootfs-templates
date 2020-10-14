#!/bin/sh

# add android groups
groupadd -g 1000 system
groupadd -g 1001 radio
groupadd -g 1003 android_graphics
groupadd -g 1004 android_input
groupadd -g 1005 android_audio
groupadd -g 3001 android_net_bt_admin
groupadd -g 3002 android_net_bt
groupadd -g 3003 android_inet
groupadd -g 3004 android_inet_raw
groupadd -g 3005 android_inet_admin

# add android users
useradd radio -g radio
useradd system -g system

# add mobian and _apt on android groups
usermod -a -G system,radio,android_graphics,android_input,android_audio,android_net_bt_admin,android_net_bt,android_inet,android_inet_raw,android_inet_admin mobian
usermod -g 3003 _apt
usermod -g 3003 _chrony

# halium firmware loader conflicts with ueventd one
if [ -f "/usr/lib/udev/rules.d/50-firmware.rules" ]; then
	rm /usr/lib/udev/rules.d/50-firmware.rules
fi

# create android mountpoint directories
mkdir -p /android /mnt/vendor/persist /userdata

ln -s /android/data /data
ln -s /android/system /system
ln -s /android/vendor /vendor
ln -s /android/cache /cache
ln -s /android/persist /persist
ln -s /android/product /product
ln -s /android/metadata /metadata

# enable android LXC service
systemctl enable lxc@android

