## Bash Scripting Conventions
Scripting conventions are needed, especially with Bash, as things can get rather wild if not.
Follow them, they try to avoid havoc and chaos.
### General
 * Include a #!/bin/bash header as the first line of your file.
<pre><code>#!/bin/bash
</code></pre>
 * You may have a header written in the style of:
<pre><code># Written by Dan Fruehauf <malkodan@gmail.com>
</code></pre>
 * Indent everything with tabs and not with spaces!
   * And if you are indenting with space, be consistent with it!
 * In case a script was misused, create a usage() function and have it's output go to stderr instead of stdout. This can be achieved by:
<pre><code>	usage() {
		echo "Usage: "`basename $0`" parameters" 1>&2
		exit 2
	}
</code></pre>
 * If using for any reason in your script *rm -rf $VARIABLE*, make sure $VARIABLE is not empty, and not '/':
<pre><code>if [ x"$VARIABLE" != x ] && [ "$VARIABLE" != "/" ]; then
	rm -rf $VARIABLE
else
	echo "Critical: tried to delete '$VARIABLE'" 1>&2
	exit 1
fi
</code></pre>
 * In case there is a use for a temporary file, use *mktemp* to generate it and make sure to remove it:
<pre><code>local temp_filename=`mktemp`
<<< operations with $temp_filename >>>
rm -f $temp_filename
</code></pre>
In case there's required user intervention, you MAY create a neat dialog using dialog, DON'T BE LAZY if you want people to use your scripts.

### Variables
 * Avoid global variable as much as you can, although usually common in bash scripts try to avoid them.
 * Avoid using hardcoded constants, it is better to have a read only global variable for that purpose.
 * If you do use global variables after all, document their use specifically, and declare them with capital letters:
<pre><code>GLOBAL_VARIABLE="some text"
</code></pre>
 * Use the keyword local to declare variables locally in functions. Variables declare in functions will always be with lowercase letters:
<pre><code>local variable_inside_function="some text"
</code></pre>
 * Use *declare -r* or *local -r* to declare read only variables.
 * Use *declare -i* or *local -i* to declare integer variables, it is a lot safer.
<pre><code># global read variable
declare -r READ_ONLY_VARIABLE=example
# global read only integer variable
declare -r -i READ_ONLY_INTEGER_VARIABLE
# local integer variable
local -i number_of_people_in_the_room=4
</code></pre>

### Functions
 * Create functions with clear names and specific objectives. Avoid bloated functions.
 * Function names will be in lowercase letters and underscores will separate the words, e.g.:
<pre><code>make_home_directory_for_user() {
	...
}
</code></pre>
 * Every script should have a main() function in it's end, followed by a call to it:
<pre><code>main() {
	save_the_world
}

main "$@"
</code></pre>
 * DO NOT write any code not in a function (except for the call to main() of course)
 * Use function headers to describe it's parameters and use 'shift' to retrieve variables. Avoid using $1, $2 etc, unless the function is really small, then the use of "$@" is allowed.
<pre><code># $1 - user name
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
</code></pre>
 * Return values from functions are 0 for success or anything else for failure:
<pre><code># this function bakes a cake
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
</code></pre>
 * Use a standard variable ($retval) to calculate the return value
 * Accumulating a return value in a function can be done by adding to a *$retval* variable:
<pre><code># this function does a few things
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
</code></pre>
 * When sourcing another bash file, never use '.', but the *source* keyword, that makes things easier when auditing code and grepping for external files:
<pre><code># avoid the following
. /etc/bashrc
# this is OK
source /etc/bashrc
</code></pre>
