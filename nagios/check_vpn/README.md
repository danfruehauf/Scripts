# check_vpn

http://exchange.nagios.org/directory/Plugins/Network-and-Systems-Management/check_vpn/details

check_vpn is a nagios plugin to check VPN status.

Currently the types of VPN supported are:
 * OpenVPN
 * SSH
 * L2TP
 * PPTP

## Features

check_vpn features the following:
 * Connect to a VPN using command line supplied parameters
 * Verify VPN connection succeded
 * Test if an address behind the VPN is reachable (default is http://www.google.com)
 * Support multiple VPN connection attemps at the same time, using source based routing
 * Plugin architecture allows addition of more VPN plugins easily

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

### SSH

Example:

	./check_vpn -t ssh -H ssh.vpn.com -u dan -p DUMMY_UNUSED_BY_SSH -- -o Port=4022

### L2TP

L2TP specific argument passing is still rather limited. It takes pppd options as specific argument and they should be <b>comma separated</b>.

Example:

	./check_vpn -t l2tp -H l2tp.vpn.com -u dan -p password -- mru 1410,mtu 1410

### PPTP

PPTP takes pppd options as specific arguements. <b>Don't</b> comma separate them.

Example:

	./check_vpn -t pptp -H l2tp.vpn.com -u dan -p password -- mru 1410 mtu 1410 novj novjccomp nobsdcomp

## Limitations

### Usage Of Same Device
Currently auto-allocation of devices is not "process safe", meaning that potentially two (or more) running instances may try to allocate and use the same device. This problem can be mitigated if you use the <b>-d</b> or <b>--device</b> option, so for instance if you have 3 hosts to check in nagios, the commands for each would be:

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

This was tested fully with OpenVPN, however I still need to setup a proper test environment for L2TP and PPTP.
