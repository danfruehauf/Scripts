#!/bin/bash

find_setuid_setguid_files() {
	# find all setuid and setgid files
	#find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -print
	find /usr/local -xdev -type f \( -perm -4000 -o -perm -2000 \) -print
}

redhat_run() {
	alias GET_PACKAGE_OF_FILE='rpm -qf'
	run
}

get_package_for_file_debian() {
	dpkg -S "$@" | cut -d: -f1
}

debian_run() {
	alias GET_PACKAGE_OF_FILE='get_package_for_file_debian'
	run
}

run() {
	# look for setuid or setgid files
	local tmp_sgid_suid_log=`mktemp`
	find_setuid_setguid_files > $tmp_sgid_suid_log
	for file in `cat $tmp_sgid_suid_log`; do
		local package=`$GET_PACKAGE_OF_FILE $file 2> /dev/null`
		if [ x"$package" != x ]; then
			echo "'$file' is suspicious and owned by package: '$package'"
			# we will not remove any packages, just report them
		else
			echo "'$file' is suspicious and is not owned by any packge"
			if [ "$TRASH_ORPHANED_SUID_FILES" = yes ] || [ "$TRASH_ORPHANED_SUID_FILES" = y ]; then
				echo "Moving file '$file' to '$TRASH'"
				mv $file $TRASH/
			fi
		fi
	done
	rm -f $tmp_sgid_suid_log
}

