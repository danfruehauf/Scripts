# check_vpn

http://exchange.nagios.org/directory/Plugins/Network-and-Systems-Management/check_vpn/details

check_vpn is a nagios plugin to check VPN status.

The types of VPNs currently supported are:
 * OpenVPN
 * SSH
 * L2TP
 * PPTP

Future:
 * IPSEC (using racoon road warrior client)
 * Anything else people would like to see supported

## Features

check_vpn features the following:
 * Connect to a VPN using command line supplied parameters
 * Verify VPN connection succeeded
 * Test if an address behind the VPN is reachable (default is http://www.google.com)
 * Support multiple VPN connection attempts at the same time, using source based routing
 * Does not interfere with current network communications of machine (using source based routing per connected device)
 * Plugin architecture allows addition of more VPN plugins easily

## Installation
 Installation process would be similar to the next steps for RHEL / CentOS / Debian distros.
 * Copy "check_vpn" content to: `/usr/lib64/nagios/plugins`  (check your distro where is the nagios `plugins` folder).
   You should end up with something similar to this:
   <pre>
   plugins/
   ├── check_vpn
   ├── check_vpn_plugins
   │   ├── l2tp.sh
   │   ├── openvpn.sh
   │   ├── pptp.sh
   │   └── ssh.sh
   ...
   </pre>

 * Edit sudoers file with `visudo` and make sure you have the next changes:
   * Comment the next two parameters: 
     <pre>#Defaults    requiretty
     #Defaults   !visiblepw</pre>

   * Add the next line (make sure the user and path are both correct for your installation):
     <pre>nagios  ALL=(ALL)   NOPASSWD:/usr/lib64/nagios/plugins/check_vpn</pre>

 * Define the command inside `commands.cfg`:
   <pre># check vpn
   define command{
     command_name    check_vpn
     command_line    /usr/bin/sudo $USER1$/check_vpn -l -t $ARG1$ -H $ARG2$ -u $ARG3$ -p $ARG4$ -- $ARG$5
   }</pre>

 * Use the command like so:
   <pre>define service{
     use                        generic-service
     host_name                  your_vpn_server
     service_description        PPTP VPN connection
     <strong>check_command              check_vpn!pptp!hostname_or_ip!user!password!require-mppe</strong>
     contact_groups             your_contact_group
    }</pre>


## Simple Usage

	./check_vpn -t VPN_TYPE -H REMOTE_HOST -u USERNAME -p PASSWORD -- EXTRA_ARGS

 * VPN_TYPE is one of the plugins under <i>check_vpn_plugins</i>:
   * openvpn
   * ssh
   * l2tp
   * pptp

## Plugin Specifics

### OpenVPN

Example:

	./check_vpn -t openvpn -H openvpn.vpn.com -u dan -p password -- --ca /etc/openvpn/ca.crt --config /etc/openvpn/vpn.com.conf --proto tcp

	# running on a tap device
	OPENVPN_DEVICE_PREFIX=tap ./check_vpn -t openvpn -H openvpn.vpn.com -u dan -p password -- --ca /etc/openvpn/ca.crt --config /etc/openvpn/vpn.com.conf --proto tcp

### SSH

Example:

	./check_vpn -t ssh -H ssh.vpn.com -u dan -p DUMMY_UNUSED_BY_SSH -- -o Port=4022

	# running on a tap device
	SSH_DEVICE_PREFIX=tap ./check_vpn -t ssh -H ssh.vpn.com -u dan -p DUMMY_UNUSED_BY_SSH

SSH plugin does not support password authentication. You will have to either use <b>ssh-agent</b> or <i>-i KEY_FILE</i>.

### L2TP

L2TP specific argument passing is still rather limited. It takes pppd options as specific argument and they should be <b>comma separated</b>.

Example:

	./check_vpn -t l2tp -H l2tp.vpn.com -u dan -p password -- mru 1410,mtu 1410

### PPTP

PPTP takes pppd options as specific arguments. <b>Don't</b> comma separate them.

Example:

	./check_vpn -t pptp -H pptp.vpn.com -u dan -p password -- mru 1410 mtu 1410 novj novjccomp nobsdcomp

## Locking

Running from nagios one cannot really control when checks take place. Some of the limitations listed below can be addressed by using exclusive locking with check_vpn, causing checks to run sequentially.

I've implemented rather simplistic mkdir locks but it seems to suffice, I don't like to over-engineer when not necessary.

To use locking you need ot specify <i>-l</i> or <i>--lock</i>. For instance the following will run sequentially:

	./check_vpn -l -t l2tp -H l2tp-1.vpn.com -u dan -p password &
	./check_vpn -l -t l2tp -H l2tp-2.vpn.com -u dan -p password &
	./check_vpn -l -t l2tp -H l2tp-3.vpn.com -u dan -p password &

Generally speaking I would encourage running check_vpn with the <i>--lock</i> option as it can avoid many problems. Should the lock file get stuck and undeleted for any reason please:
 * Fill in an issue of how to reproduce
 * rmdir /var/run/check_vpn

## Limitations

### TAP Device Gateway Guessing

If using TAP devices with OpenVPN, the remote gateway cannot be guessed, causing packets to not route properly. This can be overcome by running:

	REMOTE_GW=10.1.0.1 ./check_vpn -t openvpn -H vpn.openvpn.com -u dan -p my_secret_password -d tap76 -- --ca ca.crt

This will cause the source based routing line to be:

	ip route add default via 10.1.0.1 table PRIVATE_ROUTING_TABLE

Instead of:

	ip route add default dev tap76 table PRIVATE_ROUTING_TABLE

If you have any ideas about how to overcome this nicely, please advise me.

### Multiple Access

Currently auto-allocation of devices is not fully "process safe", meaning that potentially two (or more) running instances may try to allocate and use the same device. This problem can be mitigated if you use the <b>-d</b> or <b>--device</b> option, so for instance if you have 3 hosts you'd like to check, the commands for each would be:

	# host1
	./check_vpn -t openvpn -H host1.openvpn.vpn.com -u nagios_user -p nagios_password -d tun1
	# host2
	./check_vpn -t openvpn -H host2.openvpn.vpn.com -u nagios_user -p nagios_password -d tun2
	# host3
	./check_vpn -t openvpn -H host3.openvpn.vpn.com -u nagios_user -p nagios_password -d tun3

	# or the general case
	host=hostX.openvpn.vpn.com
	./check_vpn -t openvpn -H $host -u nagios_user -p nagios_password -d tun`echo $host | cut -c5`

That would completely separate them from each other, allowing every check to use a different device.

If your hosts are not really aligned with nice hostnames, another way of generating a unique device number per host is using a checksum and a hash:

	# first-host.openvpn.vpn.com
	declare -i device_number=$(expr `echo first-host.openvpn.vpn.com | cksum | cut -d' ' -f1` % 255)
	# device_number=11

	# another-host.openvpn.vpn.com
	declare -i device_number=$(expr `echo another-host.openvpn.vpn.com | cksum | cut -d' ' -f1` % 255)
	# device_number=168

This was tested fully with OpenVPN and SSH, however I still need to setup a proper test environment for L2TP and PPTP.

In case multiple access is still being an issue, please refer to the section about <b>Locking</b>.

### Same IP, Different Interface

If you may be connecting to two (or more) different servers who may assign you the same IP address, such as:

	# ifconfig
	tap0      Link encap:Ethernet  HWaddr XX:XX:XX:XX:XX:XX  
	      inet addr:10.1.0.1  Bcast:10.1.0.255  Mask:255.255.255.0
	      ...

	tap1      Link encap:Ethernet  HWaddr XX:XX:XX:XX:XX:XX  
	      inet addr:10.1.0.1  Bcast:10.1.0.255  Mask:255.255.255.0
	      ...

	tap2      Link encap:Ethernet  HWaddr XX:XX:XX:XX:XX:XX  
	      inet addr:10.1.0.1  Bcast:10.1.0.255  Mask:255.255.255.0
	      ...

The behavior in this case would be undefined. I've asked on Server Fault just to be sure and here is the link:
http://serverfault.com/questions/459919/multiple-vpn-devices-with-the-same-ip

If you are facing such a situation please refer to the section of <b>Locking</b>.
