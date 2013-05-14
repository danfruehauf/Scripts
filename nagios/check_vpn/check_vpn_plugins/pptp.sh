#!/bin/bash

#
# pptp.sh - PPTP plugin for check_vpn
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
### PPTP ###
############
declare -r PPTP_DEVICE_PREFIX=ppp
declare -i -r PPTP_PORT=1723

# returns a free vpn device
_pptp_allocate_vpn_device() {
	allocate_vpn_device $PPTP_DEVICE_PREFIX
}

# returns the vpn devices for the given lns
# $1 - lns
_pptp_vpn_device() {
	local lns=$1; shift
	local pids=`_pptp_get_pids $lns`
	local pid
	for pid in $pids; do
		if ps -p $pid --no-header -o cmd | grep -q "\b$lns\b"; then
			local device_nr=`ps -p $pid --no-header -o cmd | grep -o "unit [[:digit:]]\+" | cut -d' ' -f2`
			devices="$devices ${DEVICE_PREFIX}$device_nr"
		fi
	done
	# devices will be displayed twice, sort it out
	device=`echo $devices | tr -s " " "\n" | sort | uniq | xargs`
	echo "$devices"
}

# initiate a pptp connection
# $1 - lns - where to connect to
# $2 - username
# $3 - password
# $4 - device
_pptp_start_vpn() {
	local lns=$1; shift
	local username=$1; shift
	local password=$1; shift
	local device=$1; shift
	local -i device_nr=`echo $device | sed -e "s/^$PPTP_DEVICE_PREFIX//"`

	if ! which pptp >& /dev/nulll; then
		ERROR_STRING="Error: pptp not installed"
		return 1
	fi

	check_open_port $lns $PPTP_PORT
	if [ $? -ne 0 ]; then
		ERROR_STRING="Port '$PPTP_PORT' closed on '$lns'"
		return 1
	fi

	pptp --debug --timeout 10 $lns -- lock debug unit $device_nr nodefaultroute noauth user $username password $password "$@"
	if [ $? -ne 0 ]; then
		ERROR_STRING="Error: PPTP connection failed to '$lns'"
		return 1
	fi
}

# stops the vpn
# $1 - lns
# $2 - vpn device (optional)
_pptp_stop_vpn() {
	local lns=$1; shift
	local device=$1; shift
	if [ x"$lns" = x ]; then
		echo "lns unspecified, can't kill pptp" 1>&2
		return 1
	fi
	local pids=`_pptp_get_pids $lns $device`
	if [ x"$pids" != x ]; then
		kill $pids
	fi
}

# returns a list of pptp pids
# $1 - lns
# $2 - vpn device (optional)
_pptp_get_pids() {
	local lns=$1; shift
	local device=$1; shift
	local -i device_nr=`echo $device | sed -e "s/^$PPTP_DEVICE_PREFIX//"`

	local pptp_pids=`pgrep pptp | xargs`
	local pptp_relevant_pids
	local pid
	for pid in $pptp_pids; do
		if ps -p $pid --no-header -o cmd | grep -q "\b$lns\b"; then
			if [ x"$device" != x ]; then
				if ps -p $pid --no-header -o cmd | grep -q "\bunit $device_nr\b"; then
					pptp_relevant_pids="$pptp_relevant_pids $pid"
				fi
			else
				pptp_relevant_pids="$pptp_relevant_pids $pid"
			fi

		fi
	done
	echo $pptp_relevant_pids
}

# return true if VPN is up, false otherwise...
# $1 - lns
# $2 - vpn device (optional)
_pptp_is_vpn_up() {
	local lns=$1; shift
	local device=$1; shift
	ifconfig $device >& /dev/null && \
		ip addr show dev $device | grep -q "\binet\b"
	#local local_peer_addr=`ip -f inet addr show dev $device | grep inet | tr -s " " | cut -d' ' -f3` && \
	#local remote_peer_addr=`ip -f inet addr show dev $device | grep inet | tr -s " " | cut -d' ' -f5 | cut -d'/' -f1` && \
	#ping -W 3 -c 1 -I $local_peer_addr $remote_peer_addr >& /dev/null
}

