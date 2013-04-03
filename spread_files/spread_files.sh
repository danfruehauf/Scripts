#!/bin/bash

# spread_files.sh
# A utility to spread files from enourmosly big directories (+1000000 files and more)
# By Dan Fruehauf <malkodan@gmail.com>

declare -r PREFIX=EDIT_YOUR_PREFIX
declare -i -r MAX_FILES_PER_COMMAND=50
CURRENT_DIRECTORY_ARRAY=()

# incrementing our working directory
# $1 - max levels of depth
# $2 - max files in directory
# $3 - current level we're incrementing
increment_dir() {
	local max_levels=$1; shift
	local max_files=$1; shift
	local current_level=$1; shift
	if [ $current_level -eq 0 ]; then
		let CURRENT_DIRECTORY_ARRAY[$current_level]=${CURRENT_DIRECTORY_ARRAY[$current_level]}+1
		return
	fi

	# increment directory in current level or recurse deeper
	if [ `expr ${CURRENT_DIRECTORY_ARRAY[$current_level]} % $max_files` -eq 0 ]; then
		CURRENT_DIRECTORY_ARRAY[$current_level]=1
		let current_level=$current_level-1
		# recurse to increment upper level
		increment_dir $max_levels $max_files $current_level
	else
		let CURRENT_DIRECTORY_ARRAY[$current_level]=${CURRENT_DIRECTORY_ARRAY[$current_level]}+1
	fi
}

# prints the current directory from CURRENT_DIRECTORY_ARRAY
get_current_directory() {
	local -i level
	local directory
	for level in ${CURRENT_DIRECTORY_ARRAY[@]}; do
		directory="$directory$level/"
	done
	echo $directory
}

# moves the given files the to the destination directory
# $1 - destination directory
# $@ - files to move
move_files() {
	local dest_dir=$1; shift
	# if no files were specified, just return, no biggie...
	[ x"$2" = x ] && return
	echo mkdir -p $PREFIX/$dest_dir
	echo mv "$@" $PREFIX/$dest_dir
}

# main
# $1 - destination directory
# $2 - levels of hierarchy to build
main() {
	local directory=$1; shift
	local -i levels=$1; shift

	# validate directory
	if [ ! -d $directory ]; then
		echo "'$directory' is not a directory" 1>&2
		return 255
	fi

	if [ $levels -eq 0 ]; then
		echo "levels should be at least 1 or more"
		return 255
	fi

	local tmp_file_list=`mktemp`
	echo -n "Building file list, might take some time... "
	ls -1 $directory > $tmp_file_list
	echo "Done!!"

	# we actually need to calculate $number_of_file^($levels+1)
	# for instance:
	# files: 100,  levels: 1, max_files_in_dir: 10, calc: (100^(1/2)  = 10)
	# files: 1000, levels: 2, max_files_in_dir: 10, calc: (1000^(1/3) = 10)
	local -i total_number_of_files=`wc -l $tmp_file_list | cut -d' ' -f1`
	local -i max_files_in_dir=`echo | awk "END {print ($total_number_of_files) ^ (1/($levels+1))}" | cut -d. -f1`
	echo "Going to have up to '$max_files_in_dir' files in a directory"
	echo -n "Is that OK? (yes/no) "
	local resp
	read resp
	if [ x"$resp" != x"yes" ]; then
		return 1
	fi

	# initialize array (will start from 1 and not 0)
	for (( level=0; level<$levels; level++ )); do
		CURRENT_DIRECTORY_ARRAY[$level]=1
	done
	# since we're zero based, we need one less here...
	local -i max_levels=$levels-1

	local file files_in_command
	local current_directory=`get_current_directory`
	local -i file_nr=0
	local -i files_in_command_nr=0
	while read file; do
		files_to_move="$files_to_move $directory/$file"

		# do not stack too many files per command
		if [ $files_in_command_nr -eq $MAX_FILES_PER_COMMAND ]; then
			# flush files
			current_directory=`get_current_directory`
			move_files $current_directory $files_to_move
			files_to_move=""
			files_in_command_nr=0
		fi

		# alright, too many files in the directory, lets flush it
		if [ `expr \( $file_nr + 1 \) % $max_files_in_dir` -eq 0 ]; then
			# flush files
			current_directory=`get_current_directory`
			move_files $current_directory $files_to_move
			files_to_move=""
			files_in_command_nr=0

			# move on to next directory in hierarchy
			increment_dir $max_levels $max_files_in_dir $max_levels
		fi

		let file_nr=$file_nr+1
		let files_in_command_nr=$files_in_command_nr+1
	done < $tmp_file_list

	# finally flush remaining files
	current_directory=`get_current_directory`
	move_files $current_directory $files_to_move

	# remove the file list
	rm -f $tmp_file_list
}

main "$@"
