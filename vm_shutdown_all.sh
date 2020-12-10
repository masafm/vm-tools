#!/bin/sh
for vm in $(virsh list --name);do
    virsh shutdown $vm
done
