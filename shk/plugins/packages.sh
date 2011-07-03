#!/bin/bash

redhat_run() {
	PACKAGE_MANAGER_CACHE_DIR=/var/cache/yum
	PACKAGE_SUFFIX=rpm
	PACKAGE_SUFFIX="rpm -e"
	run
}

debian_run() {
	PACKAGE_MANAGER_CACHE_DIR=/var/cache/apt
	PACKAGE_SUFFIX=deb
	PACKAGE_REMOVAL_COMMAND="dpk -r"
	run
}

run() {
	# will remove package manager (apt/yum) caches
	if [ x"$PACKAGE_MANAGER_CACHE_DIR" != x ] && [ x"$PACKAGE_SUFFIX" != x ] && \
		[ -d $PACKAGE_MANAGER_CACHE_DIR ]; then
		find $PACKAGE_MANAGER_CACHE_DIR -name \*.$PACKAGE_SUFFIX -delete
	fi

	# remove packages
	local package_to_remove
	for package_to_remove in $PACKAGES_TO_REMOVE; do
		echo "Removing package '$package_to_remove'"
		eval $PACKAGE_REMOVAL_COMMAND $package_to_remove
	done
}

