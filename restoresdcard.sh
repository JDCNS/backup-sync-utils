#!/bin/bash

# Backup sdcard to designated directory
# Assumes card is /dev/mmcblk*

# Save off because I'm paranoid
THISPROG="$0"

usage()
{ 
	printf "Usage: $THISPROG imagefile [destdev]\nWhere: \n       imagefile is the image file to restore\n       destdev optionally specifies destination\n\nBe sure to run as sudo!\n\n" 1>&2
	exit 1
}

askproceed()
{
	echo "Preparing to dump ${IMAGEFILE} to ${SDCARD}"

	if [ -e "${SDCARD}" ]
	then
		echo -n "Proceed [Y/n]? "
		read YN
		if [ "$YN" = "y" -o "$YN" = "Y" -o "$YN." = "." ]
		then
			return 1
		else
			echo -n "Would you prefer to specify destination? "
			read YN
			if [ "$YN" = "y" -o "$YN" = "Y" ]
			then
				echo -n "Input SD Card location: "
				read SDCARD
				askproceed
				return $?
			else
				return 0
			fi
		fi
	else
		echo "Destination ${SDCARD} does not exist!"
		echo -n "Would you like to specify a new destination? "
		read YN
		if [ "$YN" = "y" -o "$YN" = "Y" ]
		then
			echo -n "Input SD Card location: "
			read SDCARD
			askproceed
			return $?
		else
			return 0
		fi
	fi
}

if [ $# -lt 1 ]
then
	usage
else
	IMAGEFILE="$1"
	if [ $# > 1 ]
	then
		SDCARD="$2"
	fi
fi

if [ "$SDCARD." = "." ]
then
	# Figure out whee SD Card is
	echo "Checking for SD card"
	SDCARD=`df -h | grep "/dev/mmcblk" | cut -c-12 | uniq`
	echo "SD card found at $SDCARD"
fi

askproceed
if [ $? = 1 ]
then
	echo "Unmounting..."
	for II in `df -h | grep "/dev/mmcblk" | cut -c-14`
	do
		echo unmounting $II
		umount $II
	done


	CURTIME=`date +\%F_\%T | sed s/:/\./g`
	echo "Proceeding. Time began ${CURTIME}"
	echo
	echo "${IMAGEFILE} -->  ${SDCARD}"
	dcfldd bs=2M of="${SDCARD}" if="${IMAGEFILE}"
	echo
else
	echo "Quitting."
fi

# Finally remount it
for II in `udisks --enumerate-device-files | grep mmcblk0`
do
	udisks --mount $II
done

CURTIME=`date +\%F_\%T | sed s/:/\./g`
echo "Finished. Time ended ${CURTIME}"

