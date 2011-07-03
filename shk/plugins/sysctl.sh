#!/bin/bash

# this works both in debian and redhat environments

# where to store the ulimits parameters
ULIMITS_FILE=/etc/security/limits.d/shk.conf

# where is your sysctl file??
SYSCTL_FILE=/etc/sysctl.conf

run() {
	# set sysctl parameters
	local key
	for key in "${!KERNEL_PARAMETERS[@]}"; do
		local value=${KERNEL_PARAMETERS["$key"]}
		echo "Setting $key=$value"
		smart_add_line_to_file $SYSCTL_FILE "$key" "$key=$value"
	done

	# set ulimits
	# reset the file
	> $ULIMITS_FILE
	for key in "${!ULIMIT_PARAMETERS[@]}"; do
		local value=${ULIMIT_PARAMETERS["$key"]}
		echo "Adding limit: '$key $value'"
		echo "$key $value" >> $ULIMITS_FILE
	done

	# enable changes from /etc/sysctl.conf
	sysctl -p &> /dev/null
}

