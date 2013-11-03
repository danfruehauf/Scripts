#!/bin/bash

configuration_vars() {
	# here be configuration variables, they are global
	CAKE_INGREDIENTS="flower sugar eggs fresh-cream"

	# we'll put the cake in this location
	CAKE_FILE=/home/cake
	CAKE_SIZE=40

	# we'll bake the cake in this oven
	OVEN=/usr/bin/oven
	OVEN=cat

	local -i i=0
	HOST_IP[$i]="192.168.8.211"; let i=$i+1
	HOST_IP[$i]="192.168.8.210"; let i=$i+1
}

##########################################################################################
######################### PRIVATE UTILITY FUNCTIONS!!! ###################################
##########################################################################################

SSH_OPTIONS="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SCP="scp $SSH_OPTIONS"
SSH="ssh $SSH_OPTIONS"
REMOTE_USER=root

# simply creates a new ssh key if needed and puts it in its regular place
create_ssh_key() {
	if [ ! -f ~/.ssh/id_dsa.pub ] || [ ! -f ~/.ssh/id_dsa ]; then
		echo "no ssh key found, creating one."
		ssh-keygen -t dsa -f ~/.ssh/id_dsa -N "" || exit 1
		cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys || exit 1
	fi
}

# $1 - host to exchange ssh key with
exchange_key_with_host() {
	local host=$1; shift
	echo "Please enter password for $REMOTE_USER@$host if required :"
	# i'd use here scp -r, but for some reason it recursed to inifinity and didn't copy what i needed
	cat ~/.ssh/authorized_keys | ssh $REMOTE_USER@$host "cat > authorized_keys; mkdir -p .ssh; mv authorized_keys .ssh/" >& /dev/null || exit 1
	$SCP ~/.ssh/id_dsa $REMOTE_USER@$host:~/.ssh/id_dsa >& /dev/null || exit 1
	$SCP ~/.ssh/id_dsa.pub $REMOTE_USER@$host:~/.ssh/id_dsa.pub >& /dev/null || exit 1
}

configure_ssh_access() {
	create_ssh_key # will create a key if needed
	local -i i=0
	while [ x"${HOST_IP[$i]}" != x ]; do
		exchange_key_with_host ${HOST_IP[$i]}
		let i=$i+1
	done
}

########################################################################################
######################### PHASE 1 - CAKE CONFIGURATION #################################
########################################################################################
PHASE1_STEP1_prepare_ingredients() {
	local -i retval=0

	echo "Preparing ingredients"
	local ingredient
	for ingredient in $CAKE_INGREDIENTS; do
		if ! rpm -q $ingredient; then
			echo "Missing ingredient '$ingredient'"
			return 1
		fi
	done
	true
}

PHASE1_STEP2_prepare_cake() {
	echo "Preparing cake to '$CAKE_FILE' with the size of '$CAKE_SIZE'"
	dd if=/dev/urandom of=$CAKE_FILE bs=$CAKE_SIZE count=1
}
##########################################################################################
######################### PHASE 2 - BAKING THE CAKE! #####################################
##########################################################################################

PHASE2_STEP1_bake_cake() {
	local tmp_baked_cake=`mktemp`
	echo "Baking '$CAKE_FILE' in '$OVEN'"
	$OVEN $CAKE_FILE > $tmp_baked_cake && \
	mv $tmp_baked_cake $CAKE_FILE
}

# a suffix of '___SINGLE_HOST' means we'll run this function on just one host - the first one defined
PHASE2_STEP1_taste_cake___SINGLE_HOST() {
	# we need to taste just one cake, yeah!
	echo "'$CAKE_FILE' tastes like '"`md5sum $CAKE_FILE`"'"
}

##########################################################################################
######################### MACRO FUNCTIONS ################################################
##########################################################################################
run_function_on_node() {
	local host=$1; shift
	local -i retval=0
	# temporary name for script
	local script_basename=`basename $0`
	local script_name=`mktemp -u`
	if ! $SCP $0 $REMOTE_USER@$host:$script_name >& /dev/null; then
		echo "Script failed running on $host" 1>&2
		retval=2
	fi

	if ! $SSH $REMOTE_USER@$host "$script_name $*"; then
		echo "Script failed running on $host" 1>&2
		retval=2
	fi

	# cleanup the script we copied
	$SSH $REMOTE_USER@$host "rm -f /tmp/$script_name"

	return $retval
}

# returns true if the given step should ben ran on just one host
is_step_single_host() {
	local step=$1; shift
	echo $step | grep -q ___SINGLE_HOST
}

run_phase_on_all_hosts() {
	configure_ssh_access
	local phase=$1; shift
	echo "----------------- PHASE $phase -----------------"
	for step in `get_phase_functions $phase`; do
		if is_step_single_host $step; then
			echo "Step $step will run only on this host : (${HOST_IP[0]})!"
			run_function_on_node ${HOST_IP[0]} run_step $step
			if [ "$?" != "0" ]; then
				echo "Failed running phase $phase on $ip_addr"
				exit 2
			fi
		else
			local -i i=0
			while [ x"${HOST_IP[$i]}" != x ]; do
				local host=${HOST_IP[$i]}
				echo ""
				echo "**************************"
				echo "Running step $step on host $host"
				echo "**************************"
				if ! run_function_on_node $host run_step $step; then
					echo "Failed running phase $phase on $host"
					exit 2
				fi
				let i=$i+1
			done
		fi
	done
	echo "------------------------------------------------"
}

run_step() {
	local step=$1; shift
	if ! $step; then
		echo "running step : $step failed!!!"
		return 1
	fi
}

get_phase_functions() {
	local phase=$1; shift
	declare -f | grep "^${phase}_STEP" | cut -d' ' -f1 | sort
}

configure_new_cluster() {
	# Run phase 1
	run_phase_on_all_hosts PHASE1

	# Run phase 2
	run_phase_on_all_hosts PHASE2
}

##########################################################################################
##########################################################################################
##########################################################################################

usage() {
	echo "$0 [-p <num>] [function name] [-h]
options may be:
  function name          Run the specified function
  -p <num>               Run phase #<num>
  -h                     Help
"
}

process_args() {
	echo $1 | grep -q -- ^-
	if [ "$?" == "0" ]; then
		# arg is a switch, i.e. -p5
		getopts "uhup:" OPTION

		case $OPTION in
			p) run_phase_on_all_hosts PHASE$OPTARG ;;
			h) usage ;;
			u) usage ;;
		esac
	else
		# arg is probably a function name (with params)
		$*
	fi
}

main() {
	configuration_vars

	if [ -n "$1" ]; then
		process_args $*
	else
		configure_new_cluster
	fi
}

main $*
