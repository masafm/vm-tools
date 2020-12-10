#!/bin/sh

if [ -z "$1" ];then
    echo "No target host specified"
    exit 1
fi

target=$1

for vm in $(virsh list --name);do
    virsh migrate --live --persistent $vm qemu+ssh://root@${target}/system
done
