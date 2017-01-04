# ninja-merge.sh

ninja-merge.sh is a N-way merge utility to easily merge data files from many
directories with collision handling and detection based on md5 (or other
checksum).

ninja-merge.sh is essentially a wrapper for rsync with the capability of
handling colliding files a bit better.

## Simple Usage

Merge SRC_DIR1 and SRC_DIR2 to DST_DIR, copying collisions to COLLISION_DIR:
```
$ ./ninja-merge.sh -s SRC_DIR1 -s SRC_DIR2 -i COLLISION_DIR -d DST_DIR
```

Help:
```
$ ./ninja-merge.sh --help
```
