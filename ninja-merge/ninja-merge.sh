#!/bin/bash

#
# ninja-merge.sh - a rsync wrapper which handles duplicate files better
# Copyright (C) 2013 Dan Fruehauf <malkoadan@gmail.com>
# Copyright (C) 2013 IMOS <imos.org.au>
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

# ninja merge was initially written for IMOS, handling files big amounts of
# potentially duplicate files coming from numerous sources.
#
# the operation of the script is as follows:
# * have a source directory - src_dir
# * have a destination directory - dst_dir
# * rsync -avv --ignore-existing src_dir dst_dir
#   * get the output of rsync 
#   * iterate on every file which 'exists' on both ends
#   * if the source file is not empty, use the following logic:
#     * md5 the file and the destination
#     * if the checksum is equal - ignore it
#     * if the checksum is different - copy to the inspection dir
#
# data migration ninja assumes that md5 hashing is "good enough" for the data
# sets we'll be facing.
#

# checksum to use
declare -r CHECKSUM_TYPE=md5sum

# global variable to dictate whether we should have debug messages on
declare DEBUG=no

# helper function to display a test message
# $1 - retval
# $2 - fatal? yes/no
# "$@" - test name
test_message() {
	local -i retval=$1; shift
	local fatal=$1; shift
	echo -n "$@..."
	if [ $retval -eq 0 ]; then
		echo "OK"
	else
		echo "FAILED"
		# quit if it's a fatal error
		[ "$fatal" = "yes" ] && exit $retval
	fi
}

# perform a little unit test
# $1 - source directory
# $2 - destination directory
run_tests() {
	local src_dir=$1; shift
	local index_dir=/tmp/test-index; mkdir -p $index_dir

	# copy directories to a temporary place
	# src dir
	local src_dir_tmp=`mktemp -d -u`
	cp -a "$src_dir" $src_dir_tmp
	echo "Running tests with source directory: '$src_dir_tmp'" 1>&2

	# dest dir
	local dst_dir_tmp=`mktemp -d -u`
	cp -a "$src_dir" $dst_dir_tmp
	echo "Running tests with destination directory: '$dst_dir_tmp'" 1>&2

	# inspection dir
	local inspect_dir_tmp=`mktemp -d`
	echo "Running tests with inspection directory: '$inspect_dir_tmp'" 1>&2

	# inject a file in the source directory, a file which will not exist on
	# the destination directory and will be needed to be COPIED
	echo "I HAVE TO BE COPIED" > "$src_dir_tmp/COPY ME PLEASE"
	
	# inject a file in the destination directory, and one which differs in
	# contents in the source directory - a file which will be neede to
	# be INSPECTED
	echo "I HAVE TO BE INSPECTED" > "$dst_dir_tmp/INSPECT ME PLEASE"
	echo "I HAVE TO BE INSPECTED BECAUSE I HAVE DIFFERENT CONTENTS" > \
		"$src_dir_tmp/INSPECT ME PLEASE"

	# remove old indexes if they exist in test directories
	rm -f $dst_db $src_db

	# tests pretty much begin here
	local -i retval=0
	echo
	echo "Running Tests:"
	echo "--------------"

	##############################
	# TEST #1: merge directories #
	##############################
	merge_directories $src_dir_tmp $dst_dir_tmp $inspect_dir_tmp
	local retval=$?; test_message $retval yes "Merge directories"

	#########################################
	# TEST #2: verify files to be inspected #
	#########################################
	# alright, verify results
	retval=0
	local inspect_file_checksum=`md5sum "$src_dir_tmp/INSPECT ME PLEASE" | cut -d' ' -f1`
	! test -f "$inspect_dir_tmp/INSPECT ME PLEASE.$inspect_file_checksum" && retval=1
	test_message $retval no "Files to be inspected"

	#############################
	# TEST #3: second collision #
	#############################
	# test collision on collision
	# if you see a warning here while running, it's all good!
	echo "I HAVE TO BE INSPECTED BECAUSE I HAVE DIFFERENT CONTENTS OK???" > \
		"$src_dir_tmp/INSPECT ME PLEASE"
	merge_directories $src_dir_tmp $dst_dir_tmp $inspect_dir_tmp
	local inspect_file_checksum=`md5sum "$src_dir_tmp/INSPECT ME PLEASE" | cut -d' ' -f1`
	! test -f "$inspect_dir_tmp/INSPECT ME PLEASE.$inspect_file_checksum" && retval=1
	test_message $retval no "Files to be inspected ^ 2"
	rm -f "$src_dir_tmp/INSPECT ME PLEASE"

	#####################################################
	# TEST #4: same size, same name, different contents #
	#####################################################
	# test collision, same size
	retval=0
	echo "1234" > \
		"$src_dir_tmp/INSPECT SAME SIZE"
	echo "4567" > \
		"$dst_dir_tmp/INSPECT SAME SIZE"
	local src_inspect_file_checksum=`md5sum "$src_dir_tmp/INSPECT SAME SIZE" | cut -d' ' -f1`
	local dst_inspect_file_checksum=`md5sum "$dst_dir_tmp/INSPECT SAME SIZE" | cut -d' ' -f1`
	merge_directories $src_dir_tmp $dst_dir_tmp $inspect_dir_tmp
	! test -f "$inspect_dir_tmp/INSPECT SAME SIZE.$src_inspect_file_checksum" && retval=1
	test_message $retval no "Files to be inspected ^ 3"
	rm -f "$src_dir_tmp/INSPECT SAME SIZE"


	######################################
	# TEST #5: verify files to be copied #
	######################################
	# files to be copied
	retval=0
	! test -f "$dst_dir_tmp/COPY ME PLEASE" && retval=1
	test_message $retval no "Files to be copied"

	#############################
	# TEST #6: injecting a file #
	#############################
	retval=0
	echo "I HAVE BEEN INJECTED AND I NEED TO BE COPIED" > "$src_dir_tmp/COPY ME PLEASE AFTER UPDATE"
	merge_directories $src_dir_tmp $dst_dir_tmp $inspect_dir_tmp
	! test -f "$dst_dir_tmp/COPY ME PLEASE AFTER UPDATE" && retval=1
	test_message $retval yes "Update directory"

	################################
	# TEST #7: override empty file #
	################################
	retval=0
	echo "I HAVE CONTENTS" > "$src_dir_tmp/EMPTY FILE COLLISION"
	touch "$dst_dir_tmp/EMPTY FILE COLLISION"
	merge_directories $src_dir_tmp $dst_dir_tmp $inspect_dir_tmp
	[ `wc -c "$dst_dir_tmp/EMPTY FILE COLLISION" | cut -d' ' -f1` -eq 0 ] && reval=1
	test_message $retval yes "Empty file collision"

	# cleanup!
	rm -rf --preserve-root "$src_dir_tmp" "$dst_dir_tmp" "$inspect_dir_tmp"
	exit $retval
}

# copy file to inspection directory
# $1 - src_dir
# $2 - dst_dir (usually inspection directory)
# $3 - src_file
# $4 - source file checksum
copy_collision_file() {
	local src_dir=$1; shift
	local dst_dir=$1; shift
	local src_file=$1; shift
	local src_file_checksum=$1; shift
	# create directory
	if test -f "$dst_dir/$src_file.$src_file_checksum"; then
		echo "WARN: File '$dst_dir/$src_file.$src_file_checksum' already exists, cannot copy!" 1>&2
	else
		mkdir -p "$dst_dir/`dirname $src_file`"
		[ "$DEBUG" = yes ] && echo "INSPECT Copying '$src_dir/$src_file' -> '$dst_dir/$src_file.$src_file_checksum'" 1>&2
		cp -a "$src_dir/$src_file" "$dst_dir/$src_file.$src_file_checksum"
	fi
}

# merge src_dir to dst_dir, placing duplicate files in inspect_dir
# $1 - src_dir
# $2 - dst_dir
# $3 - inspect_dir
merge_directories() {
	local src_dir=$1; shift
	local dst_dir=$1; shift
	local inspect_dir=$1; shift
	local tmp_rsync_output=`mktemp`
	if [ "$DEBUG" = yes ]; then
		# show rsync output if in DEBUG mode
		rsync -avv --ignore-existing $src_dir/ $dst_dir/ 2>&1 | tee $tmp_rsync_output
	else
		rsync -avv --ignore-existing $src_dir/ $dst_dir/ >& $tmp_rsync_output
	fi

	# iterate on all entries which existed on dstination

	# get all collisions
	local tmp_collisions=`mktemp`
	# strip the trailing 'exists' string rsync will have there
	grep " exists$" $tmp_rsync_output | sed -e 's/ exists$//g' > $tmp_collisions
	local -i number_of_collisions=`wc -l $tmp_collisions | cut -d' ' -f1`
	[ "$DEBUG" = yes ] && echo "Directory '$src_dir' had '$number_of_collisions' collisions" 1>&2

	# if we have a LARGE number of collisions, we might as well inspect it
	if [ $number_of_collisions -gt 10000 ]; then
		local src_dir_num_files=`find $src_dir -type f | wc -l`
		local -i collision_percent=`echo "$number_of_collisions/$src_dir_num_files*100" | bc -l | cut -d. -f1`
		echo "WARN: Large number of collisions for '$src_dir', collision ratio: '$collision_percent%'" 1>&2
		if [ $number_of_collisions -eq $src_dir_num_files ]; then
			echo "WARN: Source directory '$src_dir' had a collision for every file it contains, skipping verification" 1>&2
			return
		fi
	fi

	# iterate on collisions
	IFS=$'\n'
	local file
	for file in `cat $tmp_collisions`; do
		[ "$DEBUG" = yes ] && echo "Collision on '$file'" 1>&2
		local src_file="$src_dir/$file"
		local src_file_checksum=`$CHECKSUM_TYPE "$src_file" | cut -d' ' -f1`
		local dst_file="$dst_dir/$file"
		local dst_file_checksum=`$CHECKSUM_TYPE "$dst_file" | cut -d' ' -f1`
		local -i src_file_size=`wc -c $src_file | cut -d' ' -f1`
		local -i dst_file_size=`wc -c $dst_file | cut -d' ' -f1`

		# some logic about collisions and empty files
		if [ $src_file_size -eq 0 ]; then
			# if the source file is empty - don't report a collision
			true
		elif [ $dst_file_size -eq 0 ] && [ $src_file_size -ne 0 ]; then
			# in case the destination file is empty and the source file isn't - override it
			[ "$DEBUG" = yes ] && echo "'$dst_file' is empty, overriding with '$src_file'" 1>&2
			cp $src_file $dst_file
		else
			# any other case - employ some checksums to decide what's best
			if [ "$src_file_checksum" = "$dst_file_checksum" ]; then
				[ "$DEBUG" = yes ] && echo "Collision on '$file' is a non issue, checksums are the same" 1>&2
			else
				[ "$DEBUG" = yes ] && echo "Collision on '$file', moving to inspection directory" 1>&2
				copy_collision_file $src_dir $inspect_dir $file $src_file_checksum
				copy_collision_file $dst_dir $inspect_dir $file $dst_file_checksum
			fi
		fi
	done
	unset IFS
	rm -f $tmp_rsync_output $tmp_collisions
}

# returns a list of directories sorted by size
# "$@" - directories to sort
sort_directories_by_size() {
	local tmp_output=`mktemp`
	local dir
	for dir in "$@"; do
		local -i size=`du -c $dir | tail -1 | cut -f1`
		echo "$size $dir" >> $tmp_output
	done
	sort -n -r $tmp_output | cut -d' ' -f2 | xargs
	rm -f $tmp_output
}

# sends an email, after execution
# $1 - email address
# $2 - destination merge
# $3 - inspection directory
# "$@" - source directories
send_email() {
	local email_address=$1; shift
	local dst_dir=$1; shift
	local inspect_dir=$1; shift

	local tmp_email_content=`mktemp`
	echo "Source directories:" >> $tmp_email_content
	for src_dir in "$@"; do
		echo "$src_dir" >> $tmp_email_content
	done
	echo "" >> $tmp_email_content

	echo "Destination directory:" >> $tmp_email_content
	echo "$dst_dir" >> $tmp_email_content
	echo "" >> $tmp_email_content

	echo "Collision directory:" >> $tmp_email_content
	echo "$inspect_dir" >> $tmp_email_content

	cat $tmp_email_content | mail -s "Ninja merge completed" $mail
	rm -f $tmp_email_content
}

# prints usage
usage() {
	echo "Usage: $0 [OPTIONS]... -s SOURCE_DIR -d DEST_DIR"
	echo "Copies files from source directory to destination directory and
avoids duplicates."
	echo "
Options:
  -s, --source               Source directories. Can be specified multiple
                             times.
  -d, --destination          Destination directory.
  -i, --inspection           Inspection directory - all rejects will end up
                             here.
  -o, --sort                 Sort source directories by size before copying.
  -t, --test                 Run test suite. Still needs source and destination
                             directories, but doesn't modify them.
  -m, --mail                 Send email to this address after execution.
  -v, --verbose              Print more debug messages."
	exit 2
}

# main
# arguments will be parsed with getopt, see usage()
main() {
	# parse options with getopt
	local tmp_getops=`getopt -o hs:d:i:otm:v --long help,source:,destination:,sort,test,mail:,verbose -- "$@"`
	[ $? != 0 ] && usage

	eval set -- "$tmp_getops"
	local src_dirs dst_dir inspect_dir mail
	local test=no
	local sort=no

	# parse the options
	while true ; do
		case "$1" in
			-h|--help) usage;;
			-s|--source) src_dirs="$src_dirs $2"; shift 2;;
			-d|--destination) dst_dir="$2"; shift 2;;
			-i|--inspection) inspect_dir="$2"; shift 2;;
			-o|--sort) sort="yes"; shift 1;;
			-t|--test) test="yes"; shift 1;;
			-m|--mail) mail="$2"; shift 2;;
			-v|--verbose) DEBUG="yes"; shift 1;;
			--) shift; break;;
			*) usage;;
		esac
	done

	# make sure src_dir exists
	src_dirs=`echo $src_dirs | sed -e 's/^ //g'`
	[ x"$src_dirs" = x ] && usage

	# test only? needs only src_dir
	# exits after test
	[ "$test" = "yes" ] && run_tests "$src_dirs"

	# make sure dst_dir exists
	[ x"$dst_dir" = x ] && usage
	[ ! -d "$dst_dir" ] && echo "Supplied destination directory does not exist: '$dst_dir'" && usage

	# make sure inspect_dir exists
	[ x"$inspect_dir" = x ] && usage
	[ ! -d "$inspect_dir" ] && echo "Supplied inspection directory does not exist: '$inspect_dir'" && usage

	# sort directories by size (can take time if directories are big)
	if [ "$sort" = "yes" ]; then
		src_dirs=`sort_directories_by_size $src_dirs`
	fi

	# do shit (copy files).
	local src_dir
	for src_dir in $src_dirs; do
		[ ! -d "$src_dir" ] && echo "Supplied source directory does not exist: '$src_dir'" && usage
		echo "Merging '$src_dir' >> '$dst_dir'" 1>&2
		merge_directories $src_dir $dst_dir $inspect_dir
	done

	# send email?
	if [ x"$mail" != x ]; then
		send_email $mail $dst_dir $inspect_dir $src_dirs
	fi
}

main "$@"
