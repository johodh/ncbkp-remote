#!/bin/bash

# this is the remote edition of ncbkp, a nextcloud backup script relying on rsync. this script is intended to be run on a LAN side machine to access a nextcloud server inside a DMZ and extract backups of nextcloud data, database and config.  

script=$(readlink -f $0)
scriptpath=$(dirname $script)

# read global settings
source $scriptpath/.global

# Log new backup session
printf "------------------\nNew backup session\n------------------" >> $SCRIPTLOG

# check if rsync is present
which rsync 2> /dev/null
if [ $? != 0 ]; then LOG e "rsync not found" >> $SCRIPTLOG && break=1; fi

# manage ssh command with keyfile
if [ ! -z $SSH_KEYFILE ]; then 
	LOG s "ssh keyfile exists. using ${SSH_KEYFILE}" >> $SCRIPTLOG
	SSH_CMD="-e ssh -i $SSH_KEYFILE"
	SSH_WITH_KEY="-i $SSH_KEYFILE"
else LOG s "proceeding without ssh keyfile" >> $SCRIPTLOG
fi  

sudo_test=$(ssh $SSH_WITH_KEY $SSH_USERHOST sudo -u $HTTPD_USER echo test)
if [ $sudo_test != test ]; then 
	LOG e "could not act as $HTTPD_USER on $SSH_USERHOST" >> $SCRIPTLOG
	exit 1
else LOG s "has privileges to act as user $HTTPD_USER on $SSH_USERHOST" >> $SCRIPTLOG
fi 

# run remote.sh at nextcloud server (as httpd user)
cat $scriptpath/.global $scriptpath/remote.sh | ssh $SSH_WITH_KEY $SSH_USERHOST sudo -u $HTTPD_USER /bin/bash >> $SCRIPTLOG

# catch remote errors, if any
if [ $? -eq 1 ]; then 
	LOG e "remote error. exiting." >> $SCRIPTLOG
	exit 1
fi 

# rsync nc data, config and db from nextcloud server to local
eval $RSYNC_CMD ${SSH_USERHOST}:$NC_DATA $RSYNC_TARGET
if [ $? != 0 ]; then 
	LOG e "local: rsync of $NC_DATA failed. there's probably more info in the rsync log." >> $SCRIPTLOG
else LOG s "local: rsync sent $NC_DATA successfully. details in rsync log." >> $SCRIPTLOG
fi

eval $RSYNC_CMD ${SSH_USERHOST}:$NC_CONFIG_PATH $RSYNC_TARGET
if [ $? != 0 ]; then 
	LOG e "local: rsync of $NC_CONFIG_PATH failed. there's probably more info in the rsync log." >> $SCRIPTLOG
else LOG s "local: rsync sent $NC_CONFIG_PATH successfully. details in rsync log." >> $SCRIPTLOG
fi

eval $RSYNC_CMD ${SSH_USERHOST}:$DB_BKP_PATH $RSYNC_TARGET
if [ $? != 0 ]; then 
	LOG e "local: rsync of database failed. there's probably more info in the rsync log." >> $SCRIPTLOG
else 
	LOG s "local: rsync sent database successfully. details in rsync log." >> $SCRIPTLOG
	mv $RSYNC_TARGET/nextcloud-db.bkp $RSYNC_TARGET/nextcloud-db-`date +%Y-%m-%d_%H-%M`.bkp
fi

# at last, turn off maintenance mode at nextcloud server
disabled=$(ssh $SSH_WITH_KEY $SSH_USERHOST "sudo -u $HTTPD_USER $OCC maintenance:mode --off" | grep -o -e disabled)
if [ -z $disabled ]; then LOG e "remote: maintenance mode might not have been disabled after backup">> $SCRIPTLOG
else LOG s "remote: maintenance mode disabled after backup" >> $SCRIPTLOG; fi
