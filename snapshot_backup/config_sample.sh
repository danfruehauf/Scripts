#!/bin/bash

# where to backup from
declare -r SRC_DIR=/home
# where to backup to
declare -r DEST_DIR=/backup
# number of snapshots to keep
declare -i -r SNAPSHOTS_NR=7
# where to take excludes from, leave blank if you don't need it...
#declare -r EXCLUDES=/home/backup-exclude
echo "Edit configuration before invokation" 1>&2; exit 15

