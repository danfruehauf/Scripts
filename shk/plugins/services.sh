#!/bin/bash

redhat_run() {
	# rehat implementation
	local service
	for service in $SERVICES_TO_STOP; do
		# disable on any runlevel
		chkconfig $service off &> /dev/null
		# stop it now!
		service $service stop &> /dev/null
	done
	run
}

debian_run() {
	# debian implementation
	local service
	for service in $SERVICES_TO_STOP; do
		# a bit awkward in debian - i must say...
		update-rc.d disable $SERVICES_TO_STOP &> /dev/null
		/etc/init.d/$service stop &> /dev/null
	done
	run
}

run() {
	true
}

