#!/bin/bash

# disable ipv6

redhat_run() {
	# redhat implementation
	if [ "$DISABLE_IPV6" = "yes" ] || [ "$DISABLE_IPV6" = "y" ]; then
		smart_add_line_to_file /etc/sysconfig/network "NETWORKING_IPV6=" "NETWORKING_IPV6=no"
		smart_add_line_to_file /etc/modprobe.conf "alias net-pf-10" "alias net-pf-10 off"
		smart_add_line_to_file /etc/modprobe.conf "alias ipv6" "alias ipv6 off"
		service ip6tables stop
		chkconfig ip6tables stop
	fi
	run
}

debian_run() {
	# much simpler on debian
	local IPV6_DISABLE_FILE=/etc/modprobe.d/00disable_ipv6
	if [ "$DISABLE_IPV6" = "yes" ] || [ "$DISABLE_IPV6" = "y" ]; then
		echo "alias net-pf-10 off" >> $IPV6_DISABLE_FILE
		echo "alias ipv6 off" >> $IPV6_DISABLE_FILE
	fi
	run
}

run() {
	true
}

