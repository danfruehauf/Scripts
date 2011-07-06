#!/bin/bash

# prefix for backup dirs
declare -r SNAPSHOT_DIR_PREFIX=daily

RSYNC_OPTIONS="-va --delete --delete-excluded"

# uses SNAPSHOT_DIR_PREFIX to determine what's the snapshot number of a snapshot
# $1 - snapshot directory name
get_snapshot_number() {
	echo $1 | cut -d'.' -f2
}

# rotates the backups
# $1 - backup dir
# $2 - snapshot dir prefix
# $3 - max snapshots
rotate() {
	local backup_dir=$1; shift || exit 2
	local snapshot_prefix=$1; shift || exit 2
	local -i max_snapshots_nr=$1; shift || exit 2

	if [ ! -d $backup_dir ]; then
		echo "Backup directory '$backup_dir' does not exist"
		return 1
	fi

	local -i total_snapshots=`ls -d1t $backup_dir/$snapshot_prefix.* 2> /dev/null | wc -l`
	local oldest_snapshot=`ls -d1t $backup_dir/$snapshot_prefix.* 2> /dev/null | tail -1` # usually a directory named 6 or 7
	let snapshots_to_remove_nr=$total_snapshots-$max_snapshots_nr+1
	if [ $snapshots_to_remove_nr -gt 1 ]; then
		# more than 1 snapshot to remove, eck...
		echo "I have $snapshots_to_remove_nr snapshots to remove"
		local snapshots_to_remove=`ls -d1t $backup_dir/$snapshot_prefix.* 2> /dev/null | tail -$snapshots_to_remove_nr | xargs`
		for snapshot_to_remove in $snapshots_to_remove; do
			echo "Removing snapshot : $snapshot_to_remove"
			rm -rf --preserve-root $snapshot_to_remove
		done
		oldest_snapshot=`ls -d1t $backup_dir/$snapshot_prefix.* 2> /dev/null | tail -1`
	fi

	local -i oldest_snapshot_nr=`get_snapshot_number $oldest_snapshot`
	local -i next_snapshot_nr
	let next_snapshot_nr=$oldest_snapshot_nr+1

	next_snapshot=$backup_dir/$snapshot_prefix.$next_snapshot_nr
	for snapshot in `ls -d1tr $backup_dir/$snapshot_prefix.* 2> /dev/null`; do
		local -i snapshot_src_nr=`get_snapshot_number $snapshot`
		if [ $snapshot_src_nr -eq 1 ] && [ $snapshot -ef $next_snapshot ]; then
			# we're done (this directory had just one backup)
			break
		elif [ $snapshot_src_nr -eq 1 ]; then
			if [ x"$recycle_dir" != x ]; then
				# if it's the first backup - attempt to recycle from the last backup
				# move X.1 to X.2
				mv $snapshot $next_snapshot
				# move X.8 to X.1
				echo "Recycling : '$recycle_dir' to '$snapshot' and hard linking '$next_snapshot' to '$snapshot'"
				mv $recycle_dir $snapshot
				# cp -al X.2 to X.1 
				# do it this way, so it won't dump X.2 into X.1
				cp -al $next_snapshot/. $snapshot
			else
				# first backup? - preserve it and hard link to the next one, then finish
				# let's see if we can recycle it...
				echo "Rotating '$snapshot' to '$next_snapshot' (Hard linking)"
				cp -al $snapshot $next_snapshot
			fi
		else
			echo "Rotating '$snapshot' to '$next_snapshot' (Moving)"
			mv $snapshot $next_snapshot
			if [ $snapshot_src_nr -eq $SNAPSHOTS_NR ]; then
				recycle_dir=$next_snapshot
			fi
		fi
		next_snapshot=$snapshot
	done
}

# $1 - src dir
# $2 - dest dir
make_snapshot() {
	local src_dir=$1; shift
	local dest_dir=$1; shift

	echo "Backing up '$src_dir' to '$dest_dir'"

	if [ x"$EXCLUDES" != x ] && [ -r $EXCLUDES ]; then
		rsync $RSYNC_OPTIONS --exclude-from="$EXCLUDES" \
			$src_dir $dest_dir
	else
		rsync $RSYNC_OPTIONS \
			$src_dir $dest_dir
	fi

	# touch last backup to really reflect time of backup
	touch $dest_dir
}

# validates a configuration file for backup
# $1 - configuration file to validate
validate_config_file() {
	local config_file=$1; shift
	(source $config_file && \
		test -d $SRC_DIR && test -d $DEST_DIR && [ -n "${SNAPSHOTS_NR:+x}" ])
}

# invokes a backup with a configuration file
# $1 - configuration file
invoke_backup() {
	local config_file=$1; shift
	(source $config_file && 
		rotate $DEST_DIR $SNAPSHOT_DIR_PREFIX $SNAPSHOTS_NR && \
		make_snapshot $SRC_DIR $DEST_DIR/$SNAPSHOT_DIR_PREFIX.1)
}

# $1 - from where to backup
# $2 - where to backup to
main() {
	local -i retval=0
	local config_file
	for config_file in `dirname $0`/config/*; do
		validate_config_file $config_file && invoke_backup $config_file || \
			echo "Failed loading configuration '$config_file'" 1>&2
		let retval=$retval+$?
	done
	return $retval
}

main "$@"
