#!/bin/bash

# this will cause the rules to sustain a reboot on most redhats
redhat_iptables_save_and_enable() {
	iptables-save > /etc/sysconfig/iptables
	chkconfig iptables on
}

redhat_run() {
	IPTABLES_ENABLE='redhat_iptables_save_and_enable'
	run
}

# it's a bit tricky in debian, comparing to redhat
# we'll save the file aside, and make it load when interfaces are brought up
debian_iptables_save_and_enable() {
	local firewall_config=/etc/firewall.conf
	iptables-save > $firewall_config
	echo "#!/bin/sh" > /etc/network/if-up.d/iptables 
	echo "iptables-restore < $firewall_config" >> /etc/network/if-up.d/iptables 
	chmod +x /etc/network/if-up.d/iptables 
}

debian_run() {
	# TODO has to be tested
	IPTABLES_ENABLE='debian_iptables_save_and_enable'
	run
}

# allow a port
# $1 - address to allow from
# $2 - port to allow
# $3 - protocol to allow
allow_port() {
	local address=$1; shift
	local port=$1; shift
	local protocol=$1; shift
	if [ x"$port" = x ] && [ x"$protocol" = x ]; then
		# allow all traffic, disregarding port
		iptables -A INPUT -s $address -j ACCEPT
	else
		iptables -A INPUT -s $address -p $protocol --dport $port -j ACCEPT
	fi
}

run() {
	# allow to forward?
	local forward_policy=DROP
	if [ "$FIREWALL_ALLOW_FORWARD" = yes ] || [ "$FIREWALL_ALLOW_FORWARD" = "y" ]; then
		# TODO add a sysctl parameter
		forward_policy=ACCEPT
	fi

	# clear firewall rules
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X
	iptables -P INPUT ACCEPT
	iptables -P FORWARD $forward_policy
	iptables -P OUTPUT ACCEPT

	# build firewall rules

	# allow loopback interface - we have to!
	iptables -A INPUT -i lo -j ACCEPT

	# iterate on addresses and allow the ports
	local address
    for address in "${!FIREWALL_RULES[@]}"; do
        local ports=${FIREWALL_RULES["$address"]}
		for open_port in $ports; do
			local port=`echo $open_port | cut -d':' -f1`
			local protocol=`echo $open_port | cut -d':' -f2`
			allow_port $address $port $protocol
		done
    done

	# preserve firewall rules & enable them
	eval $IPTABLES_SAVE_ENABLE
}

