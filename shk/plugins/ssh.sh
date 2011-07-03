#!/bin/bash

# this is unified for both debian and redhat
SSHD_CONFIG=/etc/ssh/sshd_config

redhat_run() {
	SSHD_RELOAD="service sshd reload"
	run
}

debian_run() {
	SSHD_RELOAD="/etc/init.d/ssh reload"
	run
}

run() {
	local key
	for key in "${!SSH_PARAMETERS[@]}"; do
		local value=${SSH_PARAMETERS["$key"]}
		smart_add_line_to_file /etc/ssh/sshd_config "$key" "$key $value"
	done

	# unified way to reload sshd on both redhat and debian
	eval $SSHD_RELOAD
}

