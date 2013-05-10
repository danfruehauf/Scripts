# check_vpn
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

TODO NAGIOS EXCHANGE LINK

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

	./check_vpn -t openvpn -H ssh.vpn.com -u dan -p DUMMY_UNUSED_BY_SSH -- -o Port=4022

### L2TP

L2TP specific argument passing is still rather limited. It takes pppd options as specific argument and they should be <b>comma separated</b>.

Example:

	./check_vpn -t openvpn -H l2tp.vpn.com -u dan -p password -- mru 1410,mtu 1410

### PPTP
PPTP takes pppd options as specific arguements. <b>Don't</b> comma separate them.

Example:

	./check_vpn -t openvpn -H l2tp.vpn.com -u dan -p password -- mru 1410 mtu 1410 novj novjccomp nobsdcomp

