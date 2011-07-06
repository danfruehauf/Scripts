#!/bin/bash


#############################
### FIREWALL CONFIURATION ###
#############################
declare -A FIREWALL_RULES
# 0.0.0.0/0 denotes ALL - use this to specify open ports from ALL
# This will be a default, allow SSH from anywhere - I don't want you to
# lock yourself out of the machine...
FIREWALL_RULES["0.0.0.0/0"]="ssh:tcp"
# This will allow ports 62:udp and http:tcp from 1.1.1.1
#FIREWALL_RULES["1.1.1.1/32"]="62:udp http:tcp"
# This will allow all traffic from address 2.2.2.2/32
#FIREWALL_RULES["2.2.2.2/32"]=""

# Is this machine supposed to forward packets??
FIREWALL_ALLOW_FORWARD=no
exit 1

#############################
### PACKAGE CONFIGURATION ###
#############################
PACKAGES_TO_REMOVE=""
exit 1

##############################
### SERVICES CONFIGURATION ###
##############################
SERVICES_TO_STOP="nfs samba ahavi"
exit 1

#####################
### KERNEL PARAMS ###
#####################
declare -A KERNEL_PARAMETERS
# Reboot after panic
KERNEL_PARAMETERS["kernel.panic"]=5
# Turn on execshield
KERNEL_PARAMETERS["kernel.exec-shield"]=1
KERNEL_PARAMETERS["kernel.randomize_va_space"]=1
# Most of these have the correct setting by default
# Don't reply to broadcasts. Prevents joining a smurf attack
#KERNEL_PARAMETERS["net.ipv4.icmp_echo_ignore_broadcasts"]=1
# Enable protection for bad icmp error messages
#KERNEL_PARAMETERS["net.ipv4.icmp_ignore_bogus_error_responses"]=1
# Enable syncookies for SYN flood attack protection
#KERNEL_PARAMETERS["net.ipv4.tcp_syncookies"]=1
# Enable IP spoofing protection
KERNEL_PARAMETERS["net.ipv4.conf.all.rp_filter"]=1
#KERNEL_PARAMETERS["net.ipv4.conf.default.rp_filter"]=1
# Log spoofed, source routed, and redirect packets
KERNEL_PARAMETERS["net.ipv4.conf.all.log_martians"]=1
KERNEL_PARAMETERS["net.ipv4.conf.default.log_martians"]=1
# Don't allow source routed packets
#KERNEL_PARAMETERS["net.ipv4.conf.all.accept_source_route"]=0
#KERNEL_PARAMETERS["net.ipv4.conf.default.accept_source_route"]=0
# Don't allow outsiders to alter the routing tables
#KERNEL_PARAMETERS["net.ipv4.conf.all.accept_redirects"]=0
KERNEL_PARAMETERS["net.ipv4.conf.default.accept_redirects"]=0
KERNEL_PARAMETERS["net.ipv4.conf.all.secure_redirects"]=0
KERNEL_PARAMETERS["net.ipv4.conf.default.secure_redirects"]=0
# Don't pass traffic between networks or act as a router
KERNEL_PARAMETERS["net.ipv4.ip_forward"]=0
KERNEL_PARAMETERS["net.ipv4.conf.all.send_redirects"]=0
KERNEL_PARAMETERS["net.ipv4.conf.default.send_redirects"]=0
exit 1

####################
### SHELL LIMITS ###
####################
# Nothing will be set here, but for example, use this syntax:
#ULIMIT_PARAMETERS["root hard nofile"]=392
exit 1

##################
### NETWORKING ###
##################
# Disable IPV6?
# You should!
DISABLE_IPV6=yes
exit 1

#############
### FILES ###
#############
TRASH_ORPHANED_SUID_FILES=yes
TRASH=/tmp/trash
exit 1

######################
### SSH PARAMETERS ###
######################
declare -A SSH_PARAMETERS
# Allow only the root user
#SSH_PARAMETERS["AllowUsers"]="root"
# Move SSH to a different port
#SSH_PARAMETERS["Port"]="2817"
exit 1
