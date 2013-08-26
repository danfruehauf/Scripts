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

# test a merge from source directory to a destination directory
test_merge_to_empty_directory() {
	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	local -i diff_lines=`diff -urN $SOURCE_DIR $DEST_DIR | wc -l`
	assertTrue 'destination not identical to source' "[ $diff_lines -eq 0 ]"

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null
	local -i diff_lines=`diff -urN $SOURCE_DIR $DEST_DIR | wc -l`
	assertTrue 'destination not identical to source after running merge again' \
		"[ $diff_lines -eq 0 ]"

	local -i inspect_file_nr=`ls -1 $INSPECT_DIR | wc -l`
	assertTrue 'inspection directory has no files' \
		"[ $inspect_file_nr -eq 0 ]"
}

# test a merge to an identical directory
test_merge_to_identical_directory() {
	cp -a $SOURCE_DIR/* $DEST_DIR/

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	local -i diff_lines=`diff -urN $SOURCE_DIR $DEST_DIR | wc -l`
	assertTrue 'destination not identical to source' "[ $diff_lines -eq 0 ]"
}

# make sure we can run ninja merge over and over and its idempotent
test_idempotency() {
	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	local -i diff_lines=`diff -urN $SOURCE_DIR $DEST_DIR | wc -l`
	assertTrue 'destination not identical to source' "[ $diff_lines -eq 0 ]"

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null
	local -i diff_lines=`diff -urN $SOURCE_DIR $DEST_DIR | wc -l`
	assertTrue 'destination not identical to source after running merge again' \
		"[ $diff_lines -eq 0 ]"

}

# test a merge to a directory with a canary file
test_canary_file_copied_in_merge() {
	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	rm -f "$DEST_DIR/COPY ME PLEASE"
	echo "COPY ME!!" > "$SOURCE_DIR/COPY ME PLEASE"

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	assertTrue 'canary file copied in merge' \
		"[ -f \"$DEST_DIR/COPY ME PLEASE\" ]"
}

# inject a file to be inspected
test_files_to_be_inspected() {
	# inject file in destination directory
	echo "I HAVE TO BE INSPECTED" > "$DEST_DIR/INSPECT ME PLEASE"

	# inject file with same name in source directory
	echo "I HAVE TO BE INSPECTED BECAUSE I HAVE DIFFERENT CONTENTS" > \
		"$SOURCE_DIR/INSPECT ME PLEASE"
	local inspect_file_checksum=`md5sum "$SOURCE_DIR/INSPECT ME PLEASE" | cut -d' ' -f1`

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	assertTrue 'source file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT ME PLEASE.$inspect_file_checksum\" ]"

	local inspect_file_checksum=`md5sum "$DEST_DIR/INSPECT ME PLEASE" | cut -d' ' -f1`
	assertTrue 'destination file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT ME PLEASE.$inspect_file_checksum\" ]"


	# test collision on collision
	# 'INSPECT ME PLEASE' will already exist in the inspection directory
	# make sure we handle another collision with the same name
	# if you see a warning here while running, it's all good!
	echo "I HAVE TO BE INSPECTED BECAUSE I HAVE DIFFERENT CONTENTS OK???" > \
		"$SOURCE_DIR/INSPECT ME PLEASE"

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	local inspect_file_checksum=`md5sum "$SOURCE_DIR/INSPECT ME PLEASE" | cut -d' ' -f1`
	assertTrue 'file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT ME PLEASE.$inspect_file_checksum\" ]"
}

# inject a file to be inspected with same size
test_files_to_be_inspected_same_size() {
	# test collision, same size
	echo "1234" > \
		"$SOURCE_DIR/INSPECT SAME SIZE"
	echo "4567" > \
		"$DEST_DIR/INSPECT SAME SIZE"

	local src_inspect_file_checksum=`md5sum "$SOURCE_DIR/INSPECT SAME SIZE" | cut -d' ' -f1`
	local dst_inspect_file_checksum=`md5sum "$DEST_DIR/INSPECT SAME SIZE" | cut -d' ' -f1`
	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	assertTrue 'source file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT SAME SIZE.$src_inspect_file_checksum\" ]"
	assertTrue 'destination file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT SAME SIZE.$dst_inspect_file_checksum\" ]"
}

# make sure we override empty files and prefer files with content
test_override_empty_file_in_destination() {
	echo "I HAVE CONTENTS" > "$SOURCE_DIR/EMPTY FILE COLLISION"
	touch "$DEST_DIR/EMPTY FILE COLLISION"
	local src_file_checksum=`md5sum "$SOURCE_DIR/EMPTY FILE COLLISION" | cut -d' ' -f1`

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR >& /dev/null

	# make sure no files are in the inspection directory
	local -i files_in_inspection_directory=`ls -1 $INSPECT_DIR | wc -l`
	assertTrue 'inspection directory empty' \
		"[ $files_in_inspection_directory -eq 0 ]"

	# test if destination file was overriden
	local dst_file_checksum=`md5sum "$DEST_DIR/EMPTY FILE COLLISION" | cut -d' ' -f1`
	assertTrue 'destination file overriden' \
		"[ "$src_file_checksum" = "$dst_file_checksum" ]"
}

# inject a file to be inspected in a resume
test_files_to_be_inspected_on_resume() {
	# inject file in destination directory
	echo "I HAVE TO BE INSPECTED" > "$DEST_DIR/INSPECT ME PLEASE"

	# inject file with same name in source directory
	echo "I HAVE TO BE INSPECTED BECAUSE I HAVE DIFFERENT CONTENTS" > \
		"$SOURCE_DIR/INSPECT ME PLEASE"
	local inspect_file_checksum=`md5sum "$SOURCE_DIR/INSPECT ME PLEASE" | cut -d' ' -f1`

	local resume_file=`mktemp`
	rsync -avv --ignore-existing $SOURCE_DIR/ $DEST_DIR/ >& $resume_file

	$NINJA_MERGE_EXEC -s $SOURCE_DIR -d $DEST_DIR -i $INSPECT_DIR -r $resume_file >& /dev/null

	assertTrue 'source file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT ME PLEASE.$inspect_file_checksum\" ]"

	local inspect_file_checksum=`md5sum "$DEST_DIR/INSPECT ME PLEASE" | cut -d' ' -f1`
	assertTrue 'destination file to be inspected exists in inspection directory' \
		"[ -f \"$INSPECT_DIR/INSPECT ME PLEASE.$inspect_file_checksum\" ]"

	rm -f $resume_file
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
	# load include to test
	NINJA_MERGE_EXEC=`dirname $0`/ninja-merge.sh
	SOURCE_SETUP_DIR=`mktemp -d`
	# should be a directory with some files...
	REAL_SOURCE_DIRECTORY=/etc/sysconfig
	(cp -a $REAL_SOURCE_DIRECTORY/* $SOURCE_SETUP_DIR >& /dev/null)
	DEST_DIR=`mktemp -d`
}

oneTimeTearDown() {
	rm -rf --preserve-root $SOURCE_SETUP_DIR $DEST_DIR
}

setUp() {
	SOURCE_DIR=`mktemp -d`
	INSPECT_DIR=`mktemp -d`
	cp -a $SOURCE_SETUP_DIR/* $SOURCE_DIR/
}

tearDown() {
	rm -rf --preserve-root $SOURCE_DIR $INSPECT_DIR
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
