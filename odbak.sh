#!/bin/bash
# Purpose: Automated Open Directory Backups
# Includes options to remove old backups
# Uncomment line 87 to enable removal after testing

# VARIABLES:
# Variables here may be modified to suit your needs

# Path to backup storage location
# Avoid paths with spaces
backup_path="/Users/localadmin/Documents/OD-Backups"


# Password for the OD Archive image
# MODIFY PASSWORD FOR EACH SERVER
password="MyPassword"

# Host name of the server being backed up
# Comment out one of the two following lines
# Useful for identifying backups from multiple 
# machines on remote volumes
server="server.example.com"

# Back up server admin plists - default gathers all
# services="afp ipfilter smb" to back up specific services only
services=$(serveradmin list)

# Age of backups to remove - in days
age="14"

# Variables here are internal to the script and should
# not be modified.

# Format todays timestamp as YYYYMMDD-HHMMSS
now=$(date +%Y%m%d-%H%M%S)

# Timestamped path to OD Backups
backup=$backup_path/$server/$now-OD_Backup

# Initialize Aging Variables
big_date_stamp=0
latest_backup=0
date_stamp=0
marker=0
year=0
month=0
day=0

# FUNCTIONS:

backupRemove() {
# Get only properly named backup folders
# else age calculations will fail
files=$(ls $backup_path/$server | grep OD_Backup) 

# Find the newest file in the backup folder
for file in $files; do
	date_stamp=$(echo "$file" | awk -F- '{print $2}')
	if [ "$date_stamp" \> "$big_date_stamp" ] 
	then
		big_date_stamp="$date_stamp"
		latest_backup="$file"
	fi
done
echo "The newest file is $latest_backup with time stamp $big_date_stamp"

# Break the time stamp of the latest backup into year, month and day for calculations.
year=$(echo "$big_date_stamp" | cut -c 1-4)
month=$(echo "$big_date_stamp" | cut -c 5-6)
day=$(echo "$big_date_stamp" | cut -c 7-8)

echo "Locating backups older than $age days for removal."

# Select files older than $big_date_stamp - $age for deletion
# The idea being that we only want to remove files a set amount of time older than
# the newest existing backup, rather than anything $age older than now. If the backup
# script has not run in some time, this will preserve the latest backup.
# Set the time stamp maximum age
marker=$(date -v"$year"y -v"$month"m -v"$day"d -v-"$age"d +%Y%m%d)

echo "Removing files with date stamp older than $marker :"
for file in $files; do
	date_stamp=$(echo "$file" | awk -F- '{print $2}')
	if [ "$date_stamp" \< "$marker" ]
	then
		echo "removing $backup_path/$file"
#		rm -Rf "$backup_path/$file"
	fi
done
}

backupCreate() {	
# Create the path to OD Backups and set permissions
mkdir -p $backup
chmod 770 $backup

# Create the OD backup in the new timestamped directory
od_backup=$backup/od_backup
echo "dirserv:backupArchiveParams:archivePassword = $password" > $od_backup
echo "dirserv:backupArchiveParams:archivePath = $backup/od_$now" >> $od_backup
echo "dirserv:command = backupArchive" >> $od_backup
echo "" >> $od_backup

serveradmin command < $od_backup
echo "Saved backup in $backup"

# Get server admin plists
plistpath=$backup/serviceplists
mkdir -p $plistpath
for service in $services; do
	echo "Copying $service to $plistpath"
  	serveradmin -x settings $service > $plistpath/$service.plist
# serveradmin seems to do a little better if a delay takes place here
	sleep 1
done
echo "Done!"
}

usage() {
	echo "Usage:"
	echo "./odbak.sh -r :Remove old backups and create a new one."
	echo "./odbak.sh -c :Remove old backups and exit."
	echo "./odbak.sh :Create a new backup and exit."
}

# MAIN SCRIPT

while getopts "rch" opt; do
  case $opt in
    r)
      echo "Removing old backups."
      backupRemove
      echo "Creating a new backup."
      backupCreate
      exit 0
      ;;
    c)
      echo "Removing old backups."
      backupRemove
      exit 0
     ;;
    h)
      usage
      exit 1
      ;;
    \?)
      usage
      exit 1
      ;;
  esac
done
backupCreate
exit 0