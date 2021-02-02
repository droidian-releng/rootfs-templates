#!/bin/sh

# halium firmware loader conflicts with ueventd one
if [ -f "/usr/lib/udev/rules.d/50-firmware.rules" ]; then
	rm /usr/lib/udev/rules.d/50-firmware.rules
fi

# create android users and groups
systemd-sysusers

# disable mobian MTP services
systemctl disable mobian-usb-gadget
systemctl disable umtp-responder

# enable android LXC service
systemctl enable lxc@android

