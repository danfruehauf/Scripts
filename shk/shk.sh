#!/bin/bash

# shk.sh - Simple Hardening Kit
# Written by Dan Fruehauf <malkodan@gmail.com>

# smart_add_line_to_file adds $replacement to file, and if $pattern exists
# it'll replace the whole line with $replacement
# $1 - file
# $2 - pattern
# $3 - replacement
smart_add_line_to_file() {
	local file=$1; shift
	local pattern="$1"; shift
	local replacement="$1"; shift

	# make sure the file exists and is writable
	if [ ! -w $file ]; then
		echo "either '$file' is not a file or is not writable"
		exit 1
	fi

	if grep -q "$pattern" $file; then
		if [ x"$replacement" = x ]; then
			# replacement empty? - remove the line...
			sed -i -e "\\#.*$pattern.*#d" $file
		else
			# replacement in file? - use sed to replace...
			sed -i -e "s!.*$pattern.*!$replacement!" $file
		fi
	else
		# replacement does not exist in file? - just append it
		if [ x"$replacement" != x ]; then
			echo "$replacement" >> $file
		fi
	fi
}

# returns the distro (debian and redhat supported)
get_distro() {
	if [ -f /etc/debian_version ]; then
		echo "debian"
	elif [ -f /etc/redhat-release ]; then
		echo "redhat"
	else
		echo "distro unsupported" 1>&2
		exit 1
	fi
}

# runs a single plugin
# $1 - plugin name
run_plugin() {
	local plugin=$1; shift
	if [ -x $plugin ]; then
		echo "------------------------"
		echo "Running plugin '$plugin'"
		(source $plugin && declare -f | grep -q "^${distro}_run ()" && ${distro}_run || run)
		echo "------------------------"
	fi
}

# main!
main() {
	# check if we are root
	if [ `id -u` -ne 0 ]; then
		echo "Please run this script as root" 1>&2
		return 1
	fi
	source `dirname $0`/config.sh || exit 16
	local -i retval=0
	local distro=`get_distro`
	local plugin
	if [ x"$@" != x ]; then
		for plugin in "$@"; do
			run_plugin $plugin
			let retval=$retval+$?
		done
	else
		for plugin in plugins/*; do
			run_plugin $plugin
			let retval=$retval+$?
		done
	fi
	return $retval
}

main "$@"

