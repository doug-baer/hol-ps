#!/bin/sh

# clear any existing rules
iptables --flush

#set the default policy on FORWARD to DROP
iptables -P FORWARD DROP

# allow SSH from inside the vPod
iptables -A FORWARD -s 192.168.110.0/24 -p TCP --dport 22 -j ACCEPT

# allow access to and from Google DNS
iptables -A FORWARD -p UDP -d 8.8.8.8 --dport 53 -j ACCEPT
iptables -A FORWARD -p UDP -s 8.8.8.8 --sport 53 -j ACCEPT
iptables -A FORWARD -p UDP -d 8.8.4.4 --dport 53 -j ACCEPT
iptables -A FORWARD -p UDP -s 8.8.4.4 --sport 53 -j ACCEPT

# allow RDP requests so captains don't need to disable the firewall
iptables -A FORWARD -p TCP --dport 3389 -j ACCEPT
iptables -A FORWARD -p TCP --sport 3389 -j ACCEPT

# allow ping everywhere
iptables -A FORWARD -p icmp --icmp-type 8 -s 0/0 -d 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -p icmp --icmp-type 0 -s 0/0 -d 0/0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# allow access to and from https://hol.awmdm.com 
iptables -A FORWARD -d 23.92.229.128 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 23.92.229.128 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 23.92.229.129 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 23.92.229.129 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 63.128.76.10 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 63.128.76.10 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 63.128.76.31 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 63.128.76.31 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 192.30.64.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 192.30.64.0/20 -p TCP --sport 443 -j ACCEPT

# allow access to and from Horizon hws.airwlab.com(216.235.156.83)
iptables -A FORWARD -d 216.235.156.83 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 216.235.156.83 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 216.235.156.83 -p TCP --dport 8443 -j ACCEPT
iptables -A FORWARD -s 216.235.156.83 -p TCP --sport 8443 -j ACCEPT
iptables -A FORWARD -d 216.235.156.83 -p TCP --dport 4172 -j ACCEPT
iptables -A FORWARD -s 216.235.156.83 -p TCP --sport 4172 -j ACCEPT
iptables -A FORWARD -d 216.235.156.83 -p UDP --dport 4172 -j ACCEPT
iptables -A FORWARD -s 216.235.156.83 -p UDP --sport 4172 -j ACCEPT

# allow access to and from *.notify.windows.com
iptables -A FORWARD -d 64.4.16.149 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.4.16.149 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.52.108.255 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.52.108.255 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.55.252.9 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.55.252.9 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.18.81 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.18.81 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.18.82 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.18.82 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.75.17 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.75.17 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.75.18 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.75.18 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.29.38 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.29.38 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.29.197 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.29.197 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 131.253.34.231 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 131.253.34.231 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.96.0/24 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.96.0/24 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.122.49 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.122.49 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.122.50 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.122.50 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.55.44.124 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.55.44.124 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.55.44.122 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.55.44.122 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 191.232.139.51 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 191.232.139.51 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 191.232.139.143 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 191.232.139.143 -p TCP --sport 443 -j ACCEPT

# allow access to and from *.wns.windows.com , *.notify.live.net
iptables -A FORWARD -d 64.4.16.148 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.4.16.148 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 64.4.28.0/26 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.4.28.0/26 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.55.252.4 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.55.252.4 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.52.108.0/24 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.52.108.0/24 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.55.252.100/31 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.55.252.100/31 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.55.252.122/31 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.55.252.122/31 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 65.55.252.124/30 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 65.55.252.124/30 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.55.44.123 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.55.44.123 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.55.44.125 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.55.44.125 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.55.236.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.55.236.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.96.80 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.96.80 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.96.83 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.96.83 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.96.207 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.96.207 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.96.208 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.96.208 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.98.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.98.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.100.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.100.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.122.47 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.122.47 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.122.48 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.122.48 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 157.56.124.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 157.56.124.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.18.80 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.18.80 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.18.83 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.18.83 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.29.0/24 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.29.0/24 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.72.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.72.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.75.15 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.75.15 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.75.16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.75.16 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 111.221.124.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 111.221.124.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 131.253.34.0/24 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 131.253.34.0/24 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 191.232.139.0/24 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 191.232.139.0/24 -p TCP --sport 443 -j ACCEPT

# although vCD does not support IPv6 NAT allow IPv6 access to and from *.wns.windows.com , *.notify.live.net
# NSX supports IPv6 so vCD may NAT IPv6 at some point in the future
ip6tables -A FORWARD -d 2a01:111:f004:10::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:10::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:11::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:11::/64 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:21::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:21::/64 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:20::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:20::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:20::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:20::102/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:30::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:30::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:30::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:30::102/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:31::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:31::/64 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:40::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:40::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:40::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:40::102/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:41::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:41::/64 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:50::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:50::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:50::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:50::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:51::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:51::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:a0::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:a0::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:a0::102/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:a0::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:a1::/64 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:a1::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:b0::101/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:b0::101/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:b0::102/128 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:b0::102/128 -p TCP --sport 443 -j ACCEPT
ip6tables -A FORWARD -d 2a01:111:f004:b1::/64 -p TCP --dport 443 -j ACCEPT
ip6tables -A FORWARD -s 2a01:111:f004:b1::/64 -p TCP --sport 443 -j ACCEPT

# allow access to and from VMware identity portal
iptables -A FORWARD -d 23.92.225.71 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 23.92.225.71 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 46.244.44.178 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 46.244.44.178 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 92.246.244.207 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 92.246.244.207 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 144.130.50.214 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 144.130.50.214 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 192.240.157.233 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 192.240.157.233 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 210.237.145.251 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 210.237.145.251 -p TCP --sport 443 -j ACCEPT

# allow access to and from Forcepoint IP ranges
iptables -A FORWARD -d 85.115.32.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 85.115.32.0/19 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 86.111.216.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 86.111.216.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 86.111.220.0/22 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 86.111.220.0/22 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 103.1.196.0/22 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 103.1.196.0/22 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 116.50.56.0/21 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 116.50.56.0/21 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 177.39.96.0/22 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 177.39.96.0/22 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 196.216.238.0/23 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 196.216.238.0/23 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 192.151.176.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 192.151.176.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 208.87.232.0/21 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 208.87.232.0/21 -p TCP --sport 443 -j ACCEPT

# allow access to Google Play Store for Androids
iptables -A FORWARD -d 64.18.0.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.18.0.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 64.233.160.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.233.160.0/19 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 66.102.0.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 66.102.0.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 66.249.80.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 66.249.80.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 72.14.192.0/18 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 72.14.192.0/18 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 74.125.0.0/16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 74.125.0.0/16 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 108.177.8.0/21 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 108.177.8.0/21 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 173.194.0.0/16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 173.194.0.0/16 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 207.126.144.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 207.126.144.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 209.85.128.0/17 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 209.85.128.0/17 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 216.58.192.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 216.58.192.0/19 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 216.239.32.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 216.239.32.0/19 -p TCP --sport 443 -j ACCEPT

# allow access to and from Cisco ISE AirWatch integration
iptables -A FORWARD -d 128.107.0.0/16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 128.107.0.0/16 -p TCP --sport 443 -j ACCEPT

# allow access to and from https://fonts.googleapis.com
# allow access to and from https://themes.googleusercontent.com
# allow access to and from https://play.google.com
iptables -A FORWARD -d 64.18.0.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.18.0.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 64.233.160.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 64.233.160.0/19 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 66.102.0.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 66.102.0.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 66.249.80.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 66.249.80.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 72.14.192.0/18 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 72.14.192.0/18 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 74.125.0.0/16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 74.125.0.0/16 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 173.194.0.0/16 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 173.194.0.0/16 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 207.126.144.0/20 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 207.126.144.0/20 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 209.85.128.0/17 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 209.85.128.0/17 -p TCP --sport 443 -j ACCEPT
iptables -A FORWARD -d 216.239.32.0/19 -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s 216.239.32.0/19 -p TCP --sport 443 -j ACCEPT

# indicate that iptables has run
> ~holuser/firewall


