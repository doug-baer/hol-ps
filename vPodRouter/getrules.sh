#!/bin/sh

# first off - run the default iptables rules script
/root/iptablescfg.sh

ctr=0
sleeptime=5
timeout=60 # wait up to 5 minutes then timeout
repoFQDN=go.hol.vmware.com.s3-website-us-west-1.amazonaws.com
repoURL="http://$repoFQDN/vpodrouter"
repoIP=''
year="168"
sku="250"

# 192.168.250.1  default IP of eth5 vPodRouter
while [ "$year$sku" -eq "168250" ]
do
        if [ $ctr -eq $timeout ]
        then
                echo "LabStartup did not set eth5. Aborting..."
                /root/iptablescfg.sh
		passwd root <<END
VMware1!
VMware1!
END
                exit
        fi
        # get the vPod index number
        ip=`ifconfig eth5 | grep "inet addr" | cut -f 2 -d : | cut -f1 -d ' '`
        year=`echo "$ip" | cut -f 2 -d .`
        sku=`echo "$ip" | cut -f3 -d .`
	sku=`printf "%02d" $sku`
        if [ "$year$sku" -eq "168250" ]
        then
                echo "Waiting for Labstartup to set eth5..."
                ctr=`expr $ctr + 1`
                sleep $sleeptime
        fi
done

rulefile="$year$sku.sh"

while [ "$repoIP" = '' ]
do
        if [ $ctr -eq $timeout ]
        then
                echo "Cannot determine $repoFQDN IP. Exit."
                /root/iptablescfg.sh
		passwd root <<END
VMware1!
VMware1!
END
                exit
        fi
        echo "Getting current $repoFQDN IP address..."
        repoIP=`host "$repoFQDN" | grep address | cut -f4 -d ' '`
        if [ "$repoIP" = '' ]
        then
                echo "Did not get $repoFQDN IP. Sleeping $sleeptime ..."
                ctr=`expr $ctr + 1`
                sleep $sleeptime
        else
                echo "$repoFQDN IP is $repoIP retrieving $rulefile"
        fi
done

cp /root/iptablescfg.sh /root/origrules.sh


# append iptablescfg.sh to allow access to $repoIP
echo "Adding $repoFQDN rules to allow access to $repoIP..."
echo "iptables -A FORWARD -d $repoIP -p TCP --dport 443 -j ACCEPT
iptables -A FORWARD -s $repoIP -p TCP --sport 443 -j ACCEPT" >> /root/iptablescfg.sh

# apply the updated rules to allow access to $repoIP
/root/iptablescfg.sh

# get the current rules file for AirWatch
echo "Retrieving $rulefile from $repoFQDN..."
wget "$repoURL/$rulefile" -O /root/$rulefile

good=`grep holuser /root/$rulefile | cut -f2 -d '/'`
if [ "$good" = "firewall" ]
then
        echo "$rulefile is good. Updating iptables..."
        # update iptablescfg.sh
        mv /root/$rulefile /root/iptablescfg.sh
        chmod 555 /root/iptablescfg.sh
        /root/iptablescfg.sh
        rm -f /root/origrules.sh
else
	echo "$rulefile is NOT good or missing. Reverting iptables..."
        mv /root/origrules.sh /root/iptablescfg.sh
	rm -f /root/$rulefile
        /root/iptablescfg.sh
	passwd root <<END
VMware1!
VMware1!
END
fi
