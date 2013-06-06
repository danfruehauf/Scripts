## Bash Scripting Conventions
Scripting conventions are needed, especially with Bash, as things can get rather wild if not.
Follow them, they try to avoid havoc and chaos.
### General
 * Include a #!/bin/bash header as the first line of your file.

	#!/bin/bash

 * You may have a header written in the style of:

	# Written by Dan Fruehauf <malkodan@gmail.com>

 * Indent everything with tabs and not with spaces!
   * And if you are indenting with space, be consistent with it!
 * If using for any reason in your script *rm -rf $VARIABLE*, make sure $VARIABLE is not empty, and not '/':

	if [ x"$VARIABLE" != x ] && [ "$VARIABLE" != "/" ]; then
		rm -rf --preserve-root $VARIABLE
	else
		echo "Critical: tried to delete '$VARIABLE'" 1>&2
		exit 1
	fi

 * In case there is a use for a temporary file, use *mktemp* to generate it and make sure to remove it:

	local temp_filename=`mktemp`
	<<< operations with $temp_filename >>>
	rm -f $temp_filename
	# what NOT to do:
	local temp_shitty_filename=/tmp/i.am.idiot.$$

### Variables
 * Avoid global variable as much as you can, although usually common in bash scripts try to avoid them.
 * Avoid using hardcoded constants, it is better to have a read only global variable for that purpose.
 * If you do use global variables after all, document their use specifically, and declare them with capital letters:

	GLOBAL_VARIABLE="some text"

 * Use the keyword local to declare variables locally in functions. Variables declare in functions will always be with lowercase letters:

	local variable_inside_function="some text"

 * Use *declare -r* or *local -r* to declare read only variables.
 * Use *declare -i* or *local -i* to declare integer variables, it is a lot safer.

	# global read variable
	declare -r READ_ONLY_VARIABLE=example
	# global read only integer variable
	declare -r -i READ_ONLY_INTEGER_VARIABLE
	# local integer variable
	local -i number_of_people_in_the_room=4

### Functions
 * Create functions with clear names and specific objectives. Avoid bloated functions.
 * Function names will be in lowercase letters and underscores will separate the words, e.g.:

	make_home_directory_for_user() {
		...
	}

 * Every script should have a main() function in it's end, followed by a call to it:

	main() {
		save_the_world
	}

	main "$@"

 * DO NOT write any code not in a function (except for the call to main() of course)
 * Use function headers to describe it's parameters and use 'shift' to retrieve variables. Avoid using $1, $2 etc, unless the function is really small, then the use of "$@" is allowed.

	# $1 - user name
	# $2 - user's home directory
	# "$@" - files to copy
	copy_files_to_user_homedir() {
		local username=$1; shift
		local user_homedir=$1; shift
		for file in "$@"; do
			cp -a $file $user_homedir
			chown $username $user_homedir/`basename $file`
		done
	}

 * Return values from functions are 0 for success or anything else for failure:

	# this function bakes a cake
	# $1 - temperature
	bake_cake() {
		local -i temperature=$1; shift
		local -i retval=0
		if [ $temperature -gt 400 ]; then
			echo "Cake has burnt!"
			retval=255
		else
			echo "Cake is alright"
			retval=0
		fi
		return $retval
	}

 * Use a standard variable ($retval) to calculate the return value
 * Accumulating a return value in a function can be done by adding to a *$retval* variable:

	# this function does a few things
	# "$@" - things to do
	do_a_few_things() {
		local -i retval=0
		local thing
		for thing in "$@"; do
			echo -n "Doing '$thing'..."
			$thing
			let retval=$retval+$?
			echo "Done!"
		done
		return $retval
	}

 * Returning a few values from a function can be done either by returning a comma (or other character) separated value to STDOUT or by assigning "reference" variables:

	# this function returns 3 random numbers
	random3() {
		echo "294,3729,737"
	}

	local random_number_tuple=`random3`
	local -i random_number1=`echo $random_number_tuple | cut -d, -f1`
	local -i random_number2=`echo $random_number_tuple | cut -d, -f2`
	local -i random_number3=`echo $random_number_tuple | cut -d, -f3`

	# or by passing variables "by reference"
	# it is using global variables indirectly, however we unset them
	# after use, so it's not THAT bad...
	# this function returns 3 random numbers
	# $1 - return value #1
	# $2 - return value #2
	# $3 - return value #3
	random3() {
		local retval_1=$1; shift
		local retval_2=$1; shift
		local retval_3=$1; shift

		eval $retval_1=\$RANDOM
		eval $retval_2=\$RANDOM
		eval $retval_3=\$RANDOM
	}

	random3 random_number1 random_number2 random_number3
	echo $random_number1 $random_number2 $random_number3
	# don't forget to unset these as they will be global...
	unset random_number1 random_number2 random_number3

 * Private functions which shouldn't be called or "exported" should usually start with an underscore:

	# public function
	hello_world() {
		_hello_world_impl
	}

	# private function
	_hello_world_impl() {
		echo "Hello world!"
	}

 * When sourcing another bash file, never use '.', but the *source* keyword, that makes things easier when auditing code and grepping for external files:

	# avoid the following
	. /etc/bashrc
	# this is OK
	source /etc/bashrc

### Usability

 * In case a script was misused, create a usage() function and have it's output go to stderr instead of stdout. This can be achieved by:

	usage() {
		echo "Usage: "`basename $0`" parameters" 1>&2
		echo "Example: "`basename $0`" -a param -b -param" 1>&2
		exit 2
	}

 * always parse options with *getopts*. It is safer and friendlier for the user. Here is a snippet for getopts:

	# main
	main() {
	# parse getopts options
	local tmp_getopts=`getopt -o hab:A:B: --long help,aopt,bopt:,Aopt:,Bopt: -- "$@"`
	[ $? != 0 ] && usage
	eval set -- "$tmp_getopts"

	# option_A and option_B takes a parameter
	# option_a and option_b don't
	local option_a option_b option_A option_B
	while true; do
		case "$1" in
			-h|--help) usage;;
			-a|--aopt) option_a=yes; shift 1;;
			-b|--bopt) option_b=yes; shift 1;;
			-A|--Aopt) option_A=$2; shift 2;;
			-B|--Bopt) option_B=$2; shift 2;;
			--) shift; break;;
			*) usage;;
		esac
	done

	# if option_a is mandatory, you can have something like
	[ x"$option_a" = x ] && usage

 * In case there's required user intervention, you MAY create a neat dialog using dialog, DON'T BE LAZY if you want people to use your scripts:

	if dialog --yesno "Are you sure you want to wipe out your whole hard drive?" 0 0; then
		echo "OMG, FAIL."; exit 2
	else
		echo "Good choice mate."
	fi

