#!/bin/bash

########## Quick Backup version 0.1 ##########
#
# This script will dump all MySQL databases to individual files per database.
# These files will be generated in a temporary "QBKP_Database" directory. After that, the script
# will backup all specified directories to a tarball and send via scp to a remote server.
# Tested on Debian.
#
# Notes:
# 1. Modify the variables below
# 2. Make sure ssh host key verification is already done and to test the script if you plan to use this script with cron.
# 3. You might need to "apt-get install expect" and adjust the "set timeout 1" at line 61
#
#
# For safety purposes, do not use root credentials here, but create a particular backup user for dumping the DBs
# Example:
#
# GRANT SELECT, LOCK TABLES, PROCESS ON *.* TO  'bkpuser'@'localhost' IDENTIFIED BY 'bkpuserpasswd';
#
# Author: dth at alterland dot net and the internet
##

########## Variables ##########

# List of directories to be backed up. Don't delete the first directory named "QBKP_Databases" .
QBKP_DIRS="QBKP_Databases a b c"

# Directory for storing backups
QBKP_STORAGEDIR="QBackups"

# For dumping the DBs
QBKP_DBUSER="bkpuser"
QBKP_DBPASS="bkpuserpasswd"

# For connecting to the remote server 
QBKP_REMOTEHOST="example.com"
QBKP_REMOTEPORT="22"
QBKP_REMOTEDIR="/home/bkp"
QBKP_REMOTEUSER="remoteuser"
QBKP_REMOTEPASS="remotepass"


########## Start ##########

# Insert current date into variable
QBKP_DAY=$(date +%Y.%m.%d)

# Create QBKP_STORAGEDIR if it doesn't exist
[ -d $QBKP_STORAGEDIR ] || mkdir -p $QBKP_STORAGEDIR

# Create temporary directory for storing the DBs
mkdir -p QBKP_Databases

# Dump DBs to files inside the temporary DBs directory "Databases"
for I in $(mysql -u $QBKP_DBUSER -p$QBKP_DBPASS -Bse 'show databases' -s --skip-column-names); do mysqldump --single-transaction -u $QBKP_DBUSER -p$QBKP_DBPASS $I > QBKP_Databases/$I.sql; done

# Compress to QBKP_STORAGEDIR
tar pczf $QBKP_STORAGEDIR/$QBKP_DAY.tar.gz $QBKP_DIRS

# Delete DBs temporary directory
rm -rf QBKP_Databases

# Send via scp
expect -c "  
   set timeout 1
   spawn scp -P $QBKP_REMOTEPORT $QBKP_STORAGEDIR/$QBKP_DAY.tar.gz $QBKP_REMOTEUSER@$QBKP_REMOTEHOST:$QBKP_REMOTEDIR/$QBKP_DAY.tar.gz
   expect yes/no { send yes\r ; exp_continue }
   expect password: { send $QBKP_REMOTEPASS\r }
   expect 100%
   sleep 1
   exit
"  
if [ -f "$QBKP_REMOTEDIR/$QBKP_DAY.tar.gz" ]; then  
  echo "Transfer completed"  
fi

# Delete Backups directory
rm -rf QBackups

########## End ##########
