#!/bin/bash

############### Nagios XI License Checker ################

# Copyright (C) 2010-2014 Nagios Enterprises, LLC
# Version 1.2 - 07/13/2018
# Version 1.3 - 02/11/2020
# Version 1.4 - 02/27/2023

# Questions/issues should be posted on the Nagios
# Support Forum at https://support.nagios.com/forum/

# Feedback/recommendations/tips can be sent to
# Ludmil Miltchev at lmiltchev@nagios.com                
 
##########################################################

### Define variables ###
PROGNAME=$(basename $0)
RELEASE="ver.1.4"
DATE="02/27/2023"

### Define error messages ###
ERROR_NOINTERNET="Error: There is no Internet connection or api.nagios.com is down"
ERROR_NOINTEGER="Error: The WARNING AND CRITICAL thresholds must be integers"
ERROR_THRESHOLDS="Error: The WARNING threshold must be larger than the CRITICAL threshold"
ERROR_NOIP="Error: Please enter a valid IP address"
ERROR_NOUSERNAME="Error: Please enter a valid username"
ERROR_NOTICKET="Error: Please enter a valid insecure login ticket"
ERROR_NOWARN="Error: Please enter a value for the WARNING threshold"
ERROR_NOCRIT="Error: Please enter a value for the CRITICAL threshold"
ERROR_UNKNOWN="Error: Wrong username, insecure login ticket, or IP address"
ERROR_FREE="Error: Free License"

### Define functions ###
# Check if Nagios XI can talk to api.nagios.com
check_connectivity() {
	ping api.nagios.com -c 3 -w 10 &> /dev/null
	if [ $? -ne 0 ]; then
		echo $ERROR_NOINTERNET
		exit
	fi
}

# Display release number
print_release() {
	echo "$RELEASE"
}

# Show usage (help)
print_help() {
	echo ""
	echo "$PROGNAME, $RELEASE, $DATE - Nagios XI License Checker"
	echo ""
	echo "Usage: ./check_license.sh -H <ip address> -u <username> -t <ticket> -w <warning> -c <critical>"
	echo ""
	echo "Requirements:"
	echo "	*The Nagios XI server has to be connected to the Internet"        
	echo "	*The user has to be an 'Admin' user"
	echo "	*The warning threshold must be greater than the critical threshold"
	echo ""
	echo "Flags:"
	echo "-H		IP address"
	echo "-u		username"
	echo "-t		insecure login ticket"
	echo "-w		Warning threshod as int"
	echo "-c		Critical threshold as int"
	echo "-h|--help 	Print help"
	echo "-v		Show version"
	echo ""
	echo "Example: ./check_license.sh -H 192.168.0.100 -u nagiosadmin -t 8ALIJK2QLvuhgWaQJn3i9gI4i7nQ4L3bi49hNqnvYU6u8fkQWm95W78uuOkBPG2n -w 30 -c 15"
	echo ""
	echo "Important: The plugin won't work for you if you have a MSP License!"
	echo ""
	exit 0
}

# Define flags/args
while getopts "H:u:t:w:c:h-helpv" option 
do
	case $option in
		H) ip=$OPTARG ;;
		u) username=$OPTARG ;;
		t) ticket=$OPTARG ;;
		w) warn=$OPTARG ;;
		c) crit=$OPTARG ;;
		h) print_help 0 ;;
		help) print_help 0 ;;
		v) print_release
		exit 0 ;; 
	esac
done

## Primitive error handling :)
# If arguments are not supplied, show the usage (help) menu
if [ $# -eq 0 ]; then
	echo ""	
	print_help
	exit 1
fi

## 'check_thresholds()' function. Make sure thresholds are integers and WARNING > CRITICAL
check_thresholds() {
while true; do
ifnum="^[0-9]+$"
	if ! [[ $warn =~ $ifnum ]] || ! [[ $crit =~ $ifnum  ]]; then
		echo $ERROR_NOINTEGER
		exit 1
	else
		break
	fi
done

if [[ $warn -le $crit ]]; then
	echo $ERROR_THRESHOLDS
	exit 1
fi
}

# Can we ping the host? Is this a valid IP address?
check_host() {
ping $ip -c 3 -w 3 &> /dev/null
if [ $? -ne 0 ]; then
	echo $ERROR_NOIP
	exit
fi	
}

# Make sure all vaiables are properly set and don't contain "-" (the "next" flag is assigned to the variable if you don't enter a value, i.e. -H <space> -u <username> ...)
wrong_arg="^[^-]+$"
if ! [[ $ip =~ $wrong_arg ]]; then
	echo $ERROR_NOIP
	exit 1
elif ! [[ $username =~ $wrong_arg ]]; then
	echo $ERROR_NOUSERNAME
	exit 1
elif ! [[ $ticket =~ $wrong_arg ]]; then
	echo $ERROR_NOTICKET
	exit 1
elif ! [[ $warn =~ $wrong_arg ]]; then
	echo $ERROR_NOWARN
	exit 1 
elif ! [[ $crit =~ $wrong_arg ]]; then
	echo $ERROR_NOCRIT
	exit 1
else
	check_thresholds	
fi

## MAIN PROGRAM
check_connectivity
check_host

# Get the number of days left before license/maintenace expires
wget --quiet --no-check-certificate "http://$ip/nagiosxi/admin/license.php?&username=$username&ticket=$ticket" -O output

# Check to see if it is a "Free" license
grep -q '[F][R][E][E]' output

if [ $? = 0 ]; then
	echo $ERROR_FREE
	rm -f /usr/local/nagios/libexec/output # Removing the output file from the libexec directory
	exit 2
fi

# Check to see if it is a "Trial" license
grep -q 'Purchase a license' output

if [ $? = 0 ]; then
	echo "Trial License"
	exit 2
fi

# Check to see if license expired
grep -q 'EXPIRED ON' output

if [ $? = 0 ]; then
echo "License Expired"
exit 2
fi

days=$(grep "Maintenance Status" output | sed 's/.*<b>\([0-9,]\+\)<\/b>.*/\1/' | tr -d ,)
rm -f /usr/local/nagios/libexec/output # Removing the output file from the libexec directory

# Status message
status=$(echo "Maintenance expires in $days days.")

# If the $days variable is empty, this may indicate that the user entered a wrong username, insecure login ticket or IP address
if [ -z "$days" ]; then
	echo $ERROR_UNKNOWN 
	exit 1
fi

# Getting the proper exit codes and displaying the status message
if [[ $days -gt $warn ]]; then
	echo "OK: $status"
	exit 0
elif [[ $days -gt $crit ]]; then
	echo "WARNING: $status"
	exit 1
elif [[ $days -le $crit ]]; then
	echo "CRITICAL: $status"
	exit 2
else 
	echo "UNKNOWN: The check failed for unknown reason."
	exit 3
fi
