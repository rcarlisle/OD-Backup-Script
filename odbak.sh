#!/bin/bash
# Purpose: Automated Open Directory Archives
# Includes options to remove old archives
# Uncomment line 96 to enable removal after testing

###############################################
### Edit below to customize for your server ###
###############################################

# Enter the Client Code between the quotes:
client_code="ZZZ"

# Path to archive storage location
# Avoid paths with spaces
# Comment out one of the two lines after updating pathname.
archive_path="/Users/ZZZZadmin/Documents/OD-Backups-Automatic"
archive_path="/Users/ZZZZadmin/Documents/OpenDirectoryArchives"

# Password for the OD Archive image
# MODIFY PASSWORD FOR EACH CLIENT
password="MyPassword"

# Host name of the server being backed up
# Comment out one of the two following lines
server="server.example.com"

# Back up server admin plists - default gathers all
# services="afp ipfilter smb" to back up specific services only
services=$(serveradmin list)

# Age of archives to remove - in days
age="14"

###############################################
###	   No Edits below this point	    ###
###############################################

# VARIABLES:

# Create lc_lient_code (lower case) using tr to modify client_code (set above):
lc_client_code=$(echo "$client_code" | tr "[:upper:]" "[:lower:]")

# Format todays timestamp as YYYYMMDD-HHMMSS
now=$(date +%Y%m%d-%H%M%S)

# Timestamped path to OD Archives
archive=$archive_path/$server/$client_code-$now-OD_Archive

# Initialize Aging Variables
big_date_stamp=0
latest_archive=0
date_stamp=0
marker=0
year=0
month=0
day=0

# FUNCTIONS:

archiveRemove() {
# Get only properly named archive folders
# else age calculations will fail
files=$(ls $archive_path/$server | grep OD_Archive) 

# Find the newest file in the archive folder
for file in $files; do
	date_stamp=$(echo "$file" | awk -F- '{print $2}')
	if [ "$date_stamp" \> "$big_date_stamp" ] 
	then
		big_date_stamp="$date_stamp"
		latest_archive="$file"
	fi
done
echo "The newest file is $latest_archive with time stamp $big_date_stamp"

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
		echo "removing $archive_path/$file"
#		rm -Rf "$archive_path/$file"
	fi
done
}

archiveCreate() {	
# Create the path to OD Archives and set permissions
mkdir -p $archive
chmod 770 $archive

# Create the OD archive in the new timestamped directory
od_backup=$archive/od_backup
echo "dirserv:backupArchiveParams:archivePassword = $password" > $od_backup
echo "dirserv:backupArchiveParams:archivePath = $archive/$lc_client_code-od_$now" >> $od_backup
echo "dirserv:command = backupArchive" >> $od_backup
echo "" >> $od_backup

serveradmin command < $od_backup
echo "Saved archive in $archive"

# Get server admin plists
plistpath=$archive/serviceplists
mkdir -p $plistpath
for service in $services; do
	echo "Copying $service to $plistpath"
  	serveradmin -x settings $service > $plistpath/$service.plist
	sleep 1
done
echo "Done!"
}

usage() {
	echo "Usage:"
	echo "./odbak.sh -r :Remove old archives and create a new one."
	echo "./odbak.sh -c :Remove old archives and exit."
	echo "./odbak.sh :Create a new archive and exit."
}

# MAIN SCRIPT

while getopts "rch" opt; do
  case $opt in
    r)
      echo "Removing old archives."
      archiveRemove
      echo "Creating a new archive."
      archiveCreate
      exit 0
      ;;
    c)
      echo "Removing old archives."
      archiveRemove
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
archiveCreate
exit 0