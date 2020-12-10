#!/bin/bash
BASEDIR="/home/mkashi/backup/$(hostname)/"
TARGET="root@fileserver"
LATESTBKUP=$(ssh $TARGET "ls $BASEDIR | tail -n 1")

if [ -n "$LATESTBKUP" ] && [ -z "$1" -o "$1" != "new" ];then
    ops="--link-dest=\"../$LATESTBKUP\""
fi

# delete backup older than 30 days
ssh $TARGET "ls -r $BASEDIR | tail -n +720 | xargs -I {} rm -rf ${BASEDIR}{}"

# run rsync
rsync -aAxXz --delete $ops --exclude={"/dev","/proc","/sys","/tmp","/run","/mnt","/media","/lost+found","/var/log","/var/cache","/var/tmp"} / /boot /boot/efi ${TARGET}:${BASEDIR}/$(date "+%Y%m%d%H%M%S")/
