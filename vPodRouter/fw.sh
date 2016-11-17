#!/bin/sh

if [ ! -n "$1" ]
then
    echo "Usage $0: [on|off]"
fi

if [ $1 = "off" ]
then
    iptables -P FORWARD ACCEPT
    echo "iptables firewall off for debug temporarily ONLY"
	# indicate that iptables is off
	rm -f ~holuser/firewall
elif [ $1 = "on" ]
then
    iptables -P FORWARD DROP
    echo "iptables firewall on"
	# indicate that iptables has run
	> ~holuser/firewall
else
    echo "Usage $0: [on|off]"
fi
