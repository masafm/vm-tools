#!/bin/sh

is_leader=$(ip a | grep 192.168.151.254)
if [ -n "$is_leader" ];then
    is_healing=$(/usr/local/bin/cluster status | grep -i GlusterFS | grep -v OK)
    if [ -n "$is_healing" ];then
	echo "GlusterFS is healing on m75s" | mail -s "GlusterFS status notice" mkashi3@gmail.com
    fi
fi
