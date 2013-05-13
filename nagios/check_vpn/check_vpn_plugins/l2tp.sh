#!/bin/bash

#
# l2tp.sh - L2TP plugin for check_vpn
# Copyright (C) 2013 Dan Fruehauf <malkoadan@gmail.com>
# Copyright (C) 2012 Lacoon Security <lacoon.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

############
### L2TP ###
############
declare -r L2TP_DEVICE_PREFIX=ppp
declare -i -r L2TP_PORT=1701

# returns a free vpn device
_l2tp_allocate_vpn_device() {
	allocate_vpn_device $L2TP_DEVICE_PREFIX
}

# returns the vpn devices for the given lns
# $1 - lns
_l2tp_vpn_device() {
	local lns=$1; shift
	local pids=`_l2tp_get_pids $lns`
	local pid
	for pid in $pids; do
		if ps -p $pid --no-header -o cmd | grep -q "\.$lns-"; then
			local l2tp_pid_file=`ps -p $pid --no-header -o cmd | grep -o "\-p .*\b" | cut -d' ' -f2`
			local device=`basename $l2tp_pid_file | cut -d. -f3- | cut -d- -f2`
			devices="$devices $device"
		fi
	done
	echo "$devices"
}

# initiate a l2tp connection
# $1 - lns - where to connect to
# $2 - username
# $3 - password
# $4 - device
_l2tp_start_vpn() {
	local lns=$1; shift
	local username=$1; shift
	local password=$1; shift
	local device=$1; shift

	if lsmod | grep -q pppol2tp; then
		echo "pppol2tp.ko is loaded, please rmmod it!" 1>&2
		return 1
	fi

	local ppp_options_file=`mktemp`
	local xl2tpd_secrect_file=`mktemp`
	local xl2tpd_config_file=`mktemp`
	local xl2tpd_control_file=`mktemp -u`
	local xl2tpd_pid_file=`mktemp -u --suffix _${lns}_${device}`
	_l2tp_generate_ppp_options $lns $username $password $device "$@" > $ppp_options_file
	_l2tp_generate_xl2tpd_options $lns $username $password $device $ppp_options_file > $xl2tpd_config_file

	# execute xl2tpd
	xl2tpd -D -c $xl2tpd_config_file -C $xl2tpd_control_file -p $xl2tpd_pid_file >& /dev/null &

	# wait for xl2tpd to come up
	local -i i=0
	while ! fuser $xl2tpd_control_file >& /dev/null; do
		sleep 1
		let i=$i+1
		if [ $i -ge 10 ]; then
			ERROR_STRING="Error: xl2tpd could not start"
			rm -f $xl2tpd_secrect_file $xl2tpd_config_file $xl2tpd_pid_file $ppp_options_file
			return 1
		fi
	done

	sleep 2
	echo "c $lns" > $xl2tpd_control_file
	# let xl2tpd have a chance to get to the ppp options file
	sleep 5

	# cleanup everything
	rm -f $xl2tpd_secrect_file $xl2tpd_config_file $xl2tpd_pid_file $ppp_options_file
}

# stops the vpn
# $1 - lns
# $2 - vpn device (optional)
_l2tp_stop_vpn() {
	local lns=$1; shift
	local device=$1; shift
	if [ x"$lns" = x ]; then
		echo "lns unspecified, can't kill l2tp" 1>&2
		return 1
	fi
	local pids=`_l2tp_get_pids $lns $device`
	if [ x"$pids" != x ]; then
		kill $pids
	fi
}

# returns a list of l2tp pids
# $1 - lns
# $2 - vpn device (optional)
_l2tp_get_pids() {
	local lns=$1; shift
	local device=$1; shift

	local xl2tpd_pids=`pgrep xl2tpd | xargs`
	echo $xl2tpd_pids
	local xl2tpd_relevant_pids
	local pid
	for pid in $xl2tpd_pids; do
		# the pid file will contain the proper format of stuff
		local xl2tpd_pid_file=`ps -p $pid --no-header -o cmd | grep -o "\-p .*\b" | cut -d' ' -f2`
		local lns_for_pid=`basename $xl2tpd_pid_file | cut -d_ -f2`
		local device_for_pid=`basename $xl2tpd_pid_file | cut -d_ -f3`
		if [ "$lns_for_pid" == "$lns" ]; then
			if [ x"$device" != x ]; then
				if [ "$device_for_pid" == "$device" ]; then
					xl2tpd_relevant_pids="$xl2tpd_relevant_pids $pid"
				fi
			else
				xl2tpd_relevant_pids="$xl2tpd_relevant_pids $pid"
			fi

		fi
	done
	echo $xl2tpd_relevant_pids
}

# return true if VPN is up, false otherwise...
# $1 - lns
# $2 - vpn device (optional)
_l2tp_is_vpn_up() {
	local lns=$1; shift
	local device=$1; shift
	ifconfig $device >& /dev/null
}

# generate ppp options file, generically
# $1 - lns - where to connect to
# $2 - username
# $3 - password
# $4 - device
# $@ - extra parameters
_l2tp_generate_ppp_options() {
	local lns=$1; shift
	local username=$1; shift
	local password=$1; shift
	local device=$1; shift
	local -i device_nr=`echo $device | sed -e "s/^$L2TP_DEVICE_PREFIX//"`
	local extra_ppp_opts=`echo "$@" | tr -s "," "\n"`

	echo "
user $username
password $password
unit $device_nr
lock
noauth
nodefaultroute
noipdefault
debug
$extra_ppp_opts"
}

# generate xl2tpd options
# $1 - ppp options file
# $2 - lns - where to connect to
# $3 - username
# $4 - password
# $5 - device
_l2tp_generate_xl2tpd_options() {
	local lns=$1; shift
	local username=$1; shift
	local password=$1; shift
	local device=$1; shift
	local ppp_options_file=$1; shift

	echo "[global]
port = 0
access control = no
[lac $lns]
name = $lns
lns = $lns
pppoptfile = $ppp_options_file
ppp debug = yes
require authentication = yes
require chap = yes
length bit = yes"
}
