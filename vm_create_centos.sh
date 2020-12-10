#!/bin/sh

if [ -z $1 ];then
    echo "Specify vm name"
    exit 2
fi

if [ -z $2 ];then
    echo "Specify memory in MB"
    exit 2
fi

if [ -z $3 ];then
    echo "Specify number of vCPUs"
    exit 2
fi

if [ -f "/var/lib/libvirt/images/$1.qcow2" ];then
    echo "/var/lib/libvirt/images/$1.qcow2 already exits"
    exit 2
fi

cp -a /var/lib/libvirt/images/template-centos81.qcow2 /var/lib/libvirt/images/$1.qcow2
virt-install --os-variant centos8 --import --noreboot --name $1 --memory=$2 --vcpus=$3 --disk=/var/lib/libvirt/images/$1.qcow2 --network bridge=br0,model=virtio
vm_sysprep-centos.sh $1
allssh systemctl reload libvirtd
