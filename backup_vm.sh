#!/bin/bash

SNAPSHOT_MAX_NUM=14
SNAPSHOT_MAX_GB_THRESH=$((10*1024*1024*1024))

if [ "$1" != "cron" ]; then
    echo "Please run this command from cron" >&2
    exit 9
fi

if [ -n "$2" ];then
    if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ];then
	SNAPSHOT_MAX_NUM=$2
    else
	echo "Invalid SNAPSHOT_MAX_NUM"
	echo "Usage: $0 cron [SNAPSHOT_MAX_NUM] [SNAPSHOT_MAX_GB_THRESH]" >&2
	exit 9
    fi
fi

if [ -n "$3" ];then
    if [[ "$3" =~ ^[0-9]+$ ]] && [ "$3" -ge 1 ];then
	SNAPSHOT_MAX_GB_THRESH=$(($3*1024*1024*1024))
    else
	echo "Invalid SNAPSHOT_MAX_GB_THRESH"
	echo "Usage: $0 cron [SNAPSHOT_MAX_NUM] [SNAPSHOT_MAX_GB_THRESH]" >&2
	exit 9
    fi
fi

timestamp=$(date '+%Y%m%d%H%M%S')
snapshot_name=${timestamp}-snap
echo "Backup start at $(date '+%Y/%m/%d %H:%M:%S')"
for host in mks-m75q-1 mks-m75q-2 mks-m75q-3;do
    vms=$(ssh $host virsh list --name | grep -v template)
    
    for vm in $vms;do
	echo "Start $vm"
	disks=$(ssh $host virsh domblklist $vm | tail -n +3 | egrep '\.qcow2$|\.img|-snap$')
	cmd="ssh $host virsh snapshot-create-as --name ${snapshot_name} --domain ${vm} --disk-only --atomic --no-metadata --quiesce"
	devs=$(echo "$disks" | awk '{print $1}')
	for dev in $devs;do
	    path=$(echo "$disks" | grep "$dev" | awk '{print $2}')
	    echo "debug: $dev:$path"
	    path_base=${path%.*}
	    # delete old snapshots
	    num_snaps=$(ls ${path_base}.* 2>/dev/null | wc -l)
	    while [ $num_snaps -ge $SNAPSHOT_MAX_NUM ];do
		snaps=($(ls ${path_base}.* 2>/dev/null))
		cmd2_opt="--verbose --wait --delete"
		for ((i=0; i<$num_snaps-1; i++));do
		    fsize=$(wc --bytes "${snaps[$i]}" | awk '{print $1}')
		    if [ $fsize -lt $SNAPSHOT_MAX_GB_THRESH ];then
			base=${snaps[$i]}
			top=${snaps[(($i+1))]}
			cmd2="ssh $host virsh blockcommit $vm $dev --base $base --top $top ${cmd2_opt} 2>&1"
			echo "debug: ${cmd2}"
			${cmd2}
			break
		    fi
		done
		if [ $i = $(($num_snaps-1)) ];then
		    top=${snaps[0]}
		    cmd2="ssh $host virsh blockcommit $vm $dev --top $top ${cmd2_opt} 2>&1"
		    echo "debug: ${cmd2}"
		    ${cmd2}
		fi
		num_snaps=$(ls ${path_base}.* 2>/dev/null | wc -l)
	    done
	done
	# take snapshot
	echo "debug: ${cmd}"
	${cmd}
    done
done

# reload libvirtd
~/bin/allssh systemctl restart libvirtd

# do rsync
ops="-avz4 --delete --no-group --progress"
rsync $ops /etc/libvirt/qemu/ rsync://mkashi@raspberrypi/backup/qemu/
rsync $ops --exclude='*.tmp' --exclude="*.${snapshot_name}" /var/lib/libvirt/images/ rsync://mkashi@raspberrypi/backup/images/

echo "Backup end at $(date '+%Y/%m/%d %H:%M:%S')"
