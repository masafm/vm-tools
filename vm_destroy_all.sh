#!/bin/sh
for vm in $(virsh list --name);do
    virsh destroy $vm
done
