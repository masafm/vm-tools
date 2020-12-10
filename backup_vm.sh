#!/bin/bash

if [ "$1" != "cron" ]; then
    echo "Please run this command from cron" >&2
    exit 9
fi

SNAPSHOT_SIZE_THRESH=10737418240
SNAPSHOT_MAX_NUM=14

timestamp=$(date '+%Y%m%d%H%M%S')
echo "Backup start at $(date '+%Y/%m/%d %H:%M:%S')"
for host in mks-m75q-1 mks-m75q-2 mks-m75q-3;do
    vms=$(ssh $host virsh list --name | grep -v template)
    snapshot_name=backup_vm-${timestamp}
    
    for vm in $vms;do
	echo "Start $vm"
	disks=$(ssh $host virsh domblklist $vm | tail -n +3 | egrep '\.qcow2$|\.img$')
	cmd="ssh $host virsh snapshot-create-as --name ${snapshot_name} --domain ${vm} --disk-only --atomic --no-metadata"
	cmd_opt=""
	snapshot_deleted=""
	while read line;do
	    dev=$(echo "$line" | awk '{print $1}')
	    path=$(echo "$line" | awk '{print $2}')
	    path_base=${path%.*}
	    path_base=${path_base%.*}
	    path_ext=${path##*.}
	    echo "$path" | grep /var/lib/libvirt/images/ >/dev/null 2>&1
	    if [ $? -eq 0 ];then
		cmd_opt=" ${cmd_opt} --diskspec ${dev},file=${path_base}.${timestamp}.${path_ext}"
	    else
		if [ -n "$dev" ];then
		    cmd_opt=" ${cmd_opt} --diskspec ${dev},snapshot=no"
		fi
	    fi
	    # delete old snapshots
	    num_snaps=$(ls ${path_base}.*.* 2>/dev/null | wc -l)
	    if [ $num_snaps -ge $SNAPSHOT_MAX_NUM ];then
		snaps=($(ls ${path_base}.*.* 2>/dev/null))
		for ((i=0; i<$num_snaps-1; i++));do
		    fsize=$(wc --bytes "${snaps[$i]}" | awk '{print $1}')
		    if [ $fsize -lt $SNAPSHOT_SIZE_THRESH ];then
			base=${snaps[$i]}
			top=${snaps[(($i+1))]}
			ssh $host virsh blockcommit $vm $dev --base $base --top $top --verbose --wait --delete 2>&1
			if [ $? -eq 0 ];then
			    tmp=${top%.*}
			    snapshot_deleted="backup_vm-${tmp##*.}"
			fi
			break
		    fi
		done
		if [ $i -eq $(($num_snaps-1)) ];then
		    echo "$vm no snapshot was taken for $dev" 1>&2
		fi
	    fi
	done < <(echo "$disks")
	# delete snapshot
	if [ -n "$snapshot_deleted" ];then
	    ssh $host virsh snapshot-delete --domain $vm --metadata $snapshot_deleted
	fi
	# take snapshot
	if [ -n "$cmd_opt" ];then
	    ${cmd}${cmd_opt}
	fi
    done
done

# do rsync
ops="-avz4 --delete --no-group --progress"
rsync $ops /etc/libvirt/qemu/ rsync://mkashi@raspberrypi/backup/qemu/
rsync $ops --exclude='*.tmp' --exclude="*.${timestamp}.*" /var/lib/libvirt/images/ rsync://mkashi@raspberrypi/backup/images/

echo "Backup end at $(date '+%Y/%m/%d %H:%M:%S')"
