# span-files.sh

`span-files.sh` is a utility to spool a large data set onto smaller partitions.
Originally used to spool a satellite data set of 35TB onto multiple 5TB HDs.

`span-files.sh` will not split large files onto multiple target partitions.

## Logic

`span-files.sh` has 3 phases:
 * index
 * span
 * copy

### Index

Generate a listing of all files to be copied and their sizes, simply stored as:
```
SIZE1 FILE1
SIZE2 FILE2
SIZE3 FILE3
```

You can also generate that yourself, in case you have that information in a
database.

Index file should be stored in `$tmp_dir/index`.

### Span

Sums file sizes and outputs `list.X` files, each file listing will serve as a
list of files to copy to a specific destination.

### Copy

Factors `rsync` commands with `--files-from=list.X` for every participating
destination device.

## Simple Usage

Spool `/data` on `/mnt/1`, `/mnt/2` and `/mnt/3`:
```
$ ./span-files -o all -t data -s /data -d /mnt/1 -d /mnt/2 -d /mnt/3
```

Available space on `/mnt/1`, `/mnt/2` and `/mnt/3` will be automatically probed
before operation starts.

### Step By Step

You can also run `span-files.sh` step by step:
```
$ ./span-files -o index -t data -s /data -d /mnt/1 -d /mnt/2 -d /mnt/3
$ ./span-files -o span -t data -s /data -d /mnt/1 -d /mnt/2 -d /mnt/3
$ ./span-files -o cp -t data -s /data -d /mnt/1 -d /mnt/2 -d /mnt/3
```

`span-files.sh` keeps state in a temporary directory, in this case - `data`.
It is done like that because indexing of the files can take a very long while
however you might find yourself needing to tune your strategy of spanning the
files - so you can just run the spanning phase a few times until you get it
right.

## Caveats

`span-files.sh` does not take into account block sizes. That is, if a file is
54 bytes for example but the filesystem block size is 4kb, this file will still
occupy 4kb instead of 54 bytes. However if your destination device has a block
size of 8kb, it will occupy 8kb on it. Ideally, you want the block size of your
source device and destination device to be the same. If they are not the same
and you are copying many small files, consider either tarring them together or
account for it by not expecting to fill every destination path to a 100%. By
default `span-files.sh` will leave 10% of free space on each device.
