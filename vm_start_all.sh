#!/bin/sh
for vm in $(virsh list --inactive --name);do
    virsh start $vm
done
