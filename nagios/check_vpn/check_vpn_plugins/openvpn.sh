#!/bin/bash

# Written by Dan Fruehauf <malkodan@gmail.com>
# Big thanks to Lacoon Security for allowing this to be GPL

###########
# OPENVPN #
###########
declare -r OPENVPN_DEVICE_PREFIX=tun
declare -i -r OPENVPN_PORT=1194

# returns a free vpn device
_openvpn_allocate_vpn_device() {
	allocate_vpn_device $OPENVPN_DEVICE_PREFIX
}

# returns the vpn devices for the given lns
# $1 - lns
_openvpn_vpn_device() {
	local lns=$1; shift
	local pids=`_openvpn_get_pids $lns`
	local pid
	for pid in $pids; do
		if ps -p $pid --no-header -o cmd | grep -q "remote $lns"; then
			local device=`ps -p $pid --no-header -o cmd | grep -o -e "dev $DEVICE_PREFIX[0-9]\+" | cut -d' ' -f2`
			devices="$devices $device"
		fi
	done
	echo "$devices"
}

# initiate an openvpn connection
# $1 - lns - where to connect to
# $2 - username
# $3 - password
# $4 - device
_openvpn_start_vpn() {
	local lns=$1; shift
	local username=$1; shift
	local password=$1; shift
	local device=$1; shift
	local -i retval=0

	check_open_port $lns $OPENVPN_PORT
	if [ $? -ne 0 ]; then
		ERROR_STRING="Port '$OPENVPN_PORT' closed on '$lns'"
		return 1
	fi

	local tmp_username_password=`mktemp`
	echo -e "$username\n$password" > $tmp_username_password
	openvpn --daemon "OpenVPN-$lns" "$@" --remote $lns --tls-exit --tls-client --dev $device --route-nopull --connect-retry 1 --persist-key --persist-tun --persist-remote-ip --persist-local-ip "$@" --script-security 2 --auth-user-pass $tmp_username_password
	local -i retval=$?
	rm -f $tmp_username_password
	if [ $retval -ne 0 ]; then
		ERROR_STRING="Error: OpenVPN connection failed to '$lns'"
	fi
	return $retval
}

# stops the vpn
# $1 - lns
# $2 - vpn device (optional)
_openvpn_stop_vpn() {
	local lns=$1; shift
	local device=$1; shift
	if [ x"$lns" = x ]; then
		echo "lns unspecified, can't kill openvpn" 1>&2
		return 1
	fi
	local pids=`_openvpn_get_pids $lns $device`
	if [ x"$pids" != x ]; then
		kill $pids
	fi
}

# returns a list of openvpn pids
# $1 - lns
# $2 - vpn device (optional)
_openvpn_get_pids() {
	local lns=$1; shift
	local device=$1; shift

	local openvpn_pids=`pgrep openvpn | xargs`
	local openvpn_relevant_pids
	local pid
	for pid in $openvpn_pids; do
		if ps -p $pid --no-header -o cmd | grep -q "\-\-remote $lns\b"; then
			if [ x"$device" != x ]; then
				if ps -p $pid --no-header -o cmd | grep -q "\-\-dev $device\b"; then
					openvpn_relevant_pids="$openvpn_relevant_pids $pid"
				fi
			else
				openvpn_relevant_pids="$openvpn_relevant_pids $pid"
			fi

		fi
	done
	echo $openvpn_relevant_pids
}

# return true if VPN is up, false otherwise...
# $1 - lns
# $2 - vpn device (optional)
_openvpn_is_vpn_up() {
	local lns=$1; shift
	local device=$1; shift
	ifconfig $device >& /dev/null
}

