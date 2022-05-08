#!/bin/sh

configure_proxy() {
	if [ -z "${http_proxy}" ]; then
		# Not needed
		echo "Proxy not specified, skipping"
		return 0
	fi

	# APT should honour the http_proxy variable, so we only need to force
	# repositories to go through the cacher.
	mkdir -p /etc/apt/sources.list.d.orig

	for repository in /etc/apt/sources.list.d/*; do
		if ! grep -q "https://" ${repository}; then
			continue
		fi

		cp ${repository} /etc/apt/sources.list.d.orig/
		sed -i 's|https://|http://HTTPS///|g' ${repository}
	done

	cat > /etc/apt/apt.conf.d/01proxy <<EOF
Acquire::http::Proxy "${http_proxy}";
EOF

	apt update
}

deconfigure_proxy() {
	if [ -z "${http_proxy}" ]; then
		# Not needed
		echo "Proxy not specified, skipping"
		return 0
	elif [ ! -e "/etc/apt/sources.list.d.orig" ]; then
		echo "Backed-up original sources.list.d directory not found!"
		return 1
	fi

	for repository in /etc/apt/sources.list.d.orig/*; do
		cp ${repository} /etc/apt/sources.list.d/
	done

	rm -rf /etc/apt/sources.list.d.orig
	rm -f /etc/apt/apt.conf.d/01proxy

	apt update
}

configure_prevent_flashing() {
	mkdir -p /etc/flash-bootimage
	cat > /etc/flash-bootimage/01prevent-flashing <<EOF
FLASH_BOOTIMAGE=no
EOF
}

deconfigure_prevent_flashing() {
	rm -f /etc/flash-bootimage/01prevent-flashing
}

case "${1}" in
	"configure")
		configure_proxy
		configure_prevent_flashing
		;;
	"deconfigure")
		deconfigure_proxy
		deconfigure_prevent_flashing
		;;
	*)
		echo "USAGE: ${0} configure|deconfigure"
		exit 1
		;;
esac
