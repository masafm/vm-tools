#!/bin/sh

echo $(ls /sys/class/net/ | grep enx | head -n1) > /sys/class/net/bond0/bonding/primary
