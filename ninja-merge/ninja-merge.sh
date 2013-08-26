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
# $4 - rsync output (optional)
merge_directories() {
	local src_dir=$1; shift
	local dst_dir=$1; shift
	local inspect_dir=$1; shift

	local tmp_rsync_output
	if [ x"$1" != x ]; then
		# support resuming ninja, if an rsync output file was supplied
		tmp_rsync_output="$1"; shift
		if [ ! -f "$tmp_rsync_output" ]; then
			echo "FATAL: Resume file '$tmp_rsync_output' does not exist"
			return 1
		fi
		echo "INFO: Resuming with file '$tmp_rsync_output'"
	else
		# no resume file supplied? no worries, we will invoke rsync...
		tmp_rsync_output=`mktemp`
		if [ "$DEBUG" = yes ]; then
			# show rsync output if in DEBUG mode
			rsync -avv --ignore-existing $src_dir/ $dst_dir/ 2>&1 | tee $tmp_rsync_output
		else
			rsync -avv --ignore-existing $src_dir/ $dst_dir/ >& $tmp_rsync_output
			local ninje_command_line=`sed -e 's/\x0/ /g' /proc/$$/cmdline`
			echo "INFO: Resume file is '$tmp_rsync_output'"
			echo "INFO: To resume, run '$ninje_command_line -r $tmp_rsync_output'"
		fi
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
		# act only if it's a file
		if [ -f "$src_dir/$file" ]; then
			local src_file="$src_dir/$file"
			local dst_file="$dst_dir/$file"

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
				# please note we're running checksums ONLY when needed as they can be
				# rather slow
				local src_file_checksum=`$CHECKSUM_TYPE "$src_file" | cut -d' ' -f1`
				local dst_file_checksum=`$CHECKSUM_TYPE "$dst_file" | cut -d' ' -f1`
				if [ "$src_file_checksum" = "$dst_file_checksum" ]; then
					[ "$DEBUG" = yes ] && echo "Collision on '$file' is a non issue, checksums are the same" 1>&2
				else
					[ "$DEBUG" = yes ] && echo "Collision on '$file', moving to inspection directory" 1>&2
					copy_collision_file $src_dir $inspect_dir $file $src_file_checksum
					copy_collision_file $dst_dir $inspect_dir $file $dst_file_checksum
				fi
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
  -r, --resume               Resume ninja merge after it stopped, using the
                             provided rsync output file.
  -o, --sort                 Sort source directories by size before copying.
  -m, --mail                 Send email to this address after execution.
  -v, --verbose              Print more debug messages."
	exit 2
}

# main
# arguments will be parsed with getopt, see usage()
main() {
	# parse options with getopt
	local tmp_getops=`getopt -o hs:d:i:r:om:v --long help,source:,destination:,inspection:,resume:,sort,mail:,verbose -- "$@"`
	[ $? != 0 ] && usage

	eval set -- "$tmp_getops"
	local src_dirs dst_dir inspect_dir mail resume_file
	local sort=no

	# parse the options
	while true ; do
		case "$1" in
			-h|--help) usage;;
			-s|--source) src_dirs="$src_dirs $2"; shift 2;;
			-d|--destination) dst_dir="$2"; shift 2;;
			-i|--inspection) inspect_dir="$2"; shift 2;;
			-r|--resume) resume_file="$2"; shift 2;;
			-o|--sort) sort="yes"; shift 1;;
			-m|--mail) mail="$2"; shift 2;;
			-v|--verbose) DEBUG="yes"; shift 1;;
			--) shift; break;;
			*) usage;;
		esac
	done

	# make sure src_dir exists
	src_dirs=`echo $src_dirs | sed -e 's/^ //g'`
	[ x"$src_dirs" = x ] && usage

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
		merge_directories $src_dir $dst_dir $inspect_dir $resume_file
	done

	# send email?
	if [ x"$mail" != x ]; then
		send_email $mail $dst_dir $inspect_dir $src_dirs
	fi
}

main "$@"
