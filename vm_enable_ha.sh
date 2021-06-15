#!/bin/sh

if [ -z $1 ];then
    echo "Specify vm name"
    exit 2
fi

if [ ! -f /root/qemu/$1.xml ];then
    echo "No /root/qemu/$1.xml"
    exit 2
fi

pcs resource create vm-$1 ocf:heartbeat:VirtualDomain config=/root/qemu/$1.xml migration_transport=ssh meta allow-migrate=true

