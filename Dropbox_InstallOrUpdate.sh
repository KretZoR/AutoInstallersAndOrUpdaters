#!/bin/bash

###############################################################################################################################################
#
#               	Install or Update Dropbox
#
# Created By: 	Jamf Nation
# Description: 	Installs or updates Dropbox
# Prerequisites: None
#
###############################################################################################################################################
#
# HISTORY
#	
#	Version: 1.1
#
# 	- v1.0 Jamf Nation, 2019-11-07 : https://www.jamf.com/jamf-nation/discussions/32726/script-to-always-download-the-latest-version-of-dropbox
#	- v1.1 Martin Kretz, 2020-02-27 : Changed download URL, unmount behavior and added functions and checks
# 
################################################################################################################################################

# Get current user
currentUser=$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')

# Curl variables
DownloadURL="https://www.dropbox.com/download?full=1&plat=mac"
MountPath="/var/tmp/DropBox Installer.dmg"
UserAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1 Safari/605.1.15"

# Function to copy application from mounted DMG to local Applications folder
CopyApp ()
{
	rm -fR "/Applications/Dropbox.app"
	Copy=$(cp -R "/Volumes/Dropbox Offline Installer/Dropbox.app" "/Applications/Dropbox.app")
	if $Copy;then
		echo "INFO - Application copied to local Applications folder"
	else 
		echo "ERROR- Could not copy files from mounted DMG to local Applications folder"
		exit 1
	fi
}

# Function to check if application is running
CheckRunning ()
{
	# If Dropbox is running kill its processes
	if pgrep "Dropbox";then
		echo "INFO - Application is currently running, trying to kill application processes"
		AppKill=$(killall "Dropbox";sleep 5)
		
		# If Dropbox kill successfull function "CopyApp" will run else script will stop with error
		if $AppKill;then
			echo "INFO - Application kill confirmed!"
			CopyApp
		else
			echo "ERROR - Could not kill application"
			exit 1
		fi
	else
		echo "INFO - Application is not running. Proceeding with install/update..."
		CopyApp
	fi
}

# Function to check if application is installed
CheckInstalled ()
{
	if [ -e "/Applications/Dropbox.app" ]; then
		echo "INFO - Application installed, checking versions."

		# Get current version of Dropbox
		DropboxCurrentVersion=$(defaults read "/Applications/Dropbox.app/Contents/Info.plist" CFBundleShortVersionString | sed -e 's/\.//g')
		echo "INFO - Current version is: $DropboxCurrentVersion"

		# Get latest version of Dropbox
	    DropboxLatestVersion=$(defaults read "/Volumes/Dropbox Offline Installer/Dropbox.app/Contents/Info.plist" CFBundleShortVersionString | sed -e 's/\.//g')
		echo "INFO - Latest version is: $DropboxLatestVersion"
		
		# If current version is lower than latest version run function "CheckRunning" else end script successfull
	    if [ "$DropboxCurrentVersion" -lt "$DropboxLatestVersion" ]; then
	    	# Copy application from mounted DMG to local Applications folder
			echo "INFO - Latest version newer than current version. Update will begin!"
			CheckRunning
	    else
			echo "INFO - Current version same or higher than latest stable version. No update needed!"
			exit 0
	    fi

	else
		echo "INFO - Appication not installed. Installation will begin!"
		CheckRunning
	fi

}

# Download DMG from vendor
echo "INFO - Downloading DMG"
curl -A "$UserAgent" -L "$DownloadURL" > "$MountPath"

# Mount DMG
echo "INFO - Mounting DMG"
hdiutil attach "$MountPath" -nobrowse

# Check if application is already installed
echo "INFO - Checking if application is installed"
CheckInstalled

# Change to other directory than installer to prevent unmount to fail
echo "INFO - Changing to other directory than installer to prevent unmount to fail"
cd /var/tmp/

# Unmount DMG
echo "INFO - Unmounting DMG"
hdiutil detach /Volumes/Dropbox\ Offline\ Installer/ -force

# Remove temporary files
echo "INFO - Removing temporary files"
rm -rf "$MountPath"

# Start application
echo "INFO - Starting application"
open -a /Applications/Dropbox.app

exit 0
