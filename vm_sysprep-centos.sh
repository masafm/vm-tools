#!/bin/sh

if [ -z $1 ];then
    echo "Specify vm name"
    exit 2
fi

virt-sysprep --enable customize,ssh-hostkeys --hostname $1 -d $1
