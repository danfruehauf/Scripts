#!/bin/bash

MOCKED_ETC_HOSTS_SIG='___MOCKED___'
ETC_HOSTS=/etc/hosts

# a utility function to easily operate on patters in a text file
# $1 - file to operate on
# $2 - pattern to search for
# $3 - replacement pattern
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

# replace source src file with dst file, preserving permissions
# $1 - src file
# $2 - dst file
replace_etc_hosts() {
	local src=$1; shift
	local dst=$1; shift
	sudo su -c "chown --reference=$dst $src && chmod --reference=$dst $src && mv $src $dst"
}

# add a mocked host
# $1 - ip address of mocked host
# "$@" - mocked hostnames
add_mock_host() {
	local ip_addr=$1; shift

	local tmp_etc_hosts=`mktemp`
	cp $ETC_HOSTS $tmp_etc_hosts

	if [ x"$1" = x ]; then
		echo "Must provide at least one hostname to mock"
		return 1
	fi

	local etc_hosts_line="$ip_addr $@ $MOCKED_ETC_HOSTS_SIG"
	echo "Mocking '$@' -> '$ip_addr'"
	smart_add_line_to_file $tmp_etc_hosts "$ip_addr" "$etc_hosts_line"
	replace_etc_hosts $tmp_etc_hosts $ETC_HOSTS
}

# delete a mocked host
# $1 - pattern of mocked host
del_mock_host() {
	local pattern=$1; shift

	local tmp_etc_hosts=`mktemp`
	cp $ETC_HOSTS $tmp_etc_hosts

	echo "Removing mocked pattern '$pattern':"
	echo "---"
	grep "$pattern.*$MOCKED_ETC_HOSTS_SIG" $tmp_etc_hosts
	echo "---"
	local mocked_etc_hosts_sig
	smart_add_line_to_file $tmp_etc_hosts "$pattern.*$MOCKED_ETC_HOSTS_SIG" ""
	replace_etc_hosts $tmp_etc_hosts $ETC_HOSTS
}

# clears all mocked hosts
clear_mock_hosts() {
	local tmp_etc_hosts=`mktemp`
	cp $ETC_HOSTS $tmp_etc_hosts

	echo "Clearing all mocked hosts:"
	show_mock_hosts

	smart_add_line_to_file $tmp_etc_hosts "$MOCKED_ETC_HOSTS_SIG" ""
	replace_etc_hosts $tmp_etc_hosts $ETC_HOSTS
}

# shows all mocked hosts
show_mock_hosts() {
	echo "---"
	grep "$MOCKED_ETC_HOSTS_SIG" $ETC_HOSTS
	echo "---"
}
