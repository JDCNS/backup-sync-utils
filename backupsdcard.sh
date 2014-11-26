#!/bin/bash

# Backup sdcard to designated directory
# Assumes card is /dev/mmcblk*

# Save off because I'm paranoid
THISPROG="$0"

usage()
{ 
	printf "Usage: $THISPROG piname destdir \nWhere: \n       piname is hostname of Pi\n       destdir is directory for image\n\nBe sure to run as sudo!\n\n" 1>&2
	exit 1
}

askproceed()
{
	echo "Preparing to dump ${SDCARD} into ${DESTDIR}/${PINAME}_${CURTIME}.img"

	if [ -d "$DESTDIR" ]
	then
		echo -n "Proceed [Y/n]? "
		read YN
		if [ "$YN" = "y" -o "$YN" = "Y" -o "$YN." = "." ]
		then
			return 1
		else
			echo -n "Would you prefer to specify source? "
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
		echo "Destination directory does not exist!"
		echo -n "Should I try to create it? "
		read YN
		if [ "$YN" = "y" -o "$YN" = "Y" ]
		then
			mkdir -p -v ${DESTDIR}
			askproceed
			return $?
		else
			return 0
		fi
	fi
}

if [ $# -lt 2 ]
then
	usage
fi

PINAME="$1"
DESTDIR="$2"
echo "$DESTDIR" | grep "[^/]$"
if [ "$?" -eq "0" ]
then
    echo "Ok."
else
    DESTDIR=`echo "$DESTDIR" | sed s'/.$//'`
    echo "Dropped trailing slash"
fi
echo "Before time"
CURTIME=`date +\%F_\%T | sed s/:/\./g`
echo "Checking for SD card"
SDCARD=`df -h | grep "/dev/mmcblk" | cut -c-12 | uniq`
echo "SD card found at $SDCARD"
askproceed

if [ $? = 1 ]
then
	echo "Proceeding ${CURTIME}." | tee -a  "${DESTDIR}/${PINAME}_${CURTIME}.log"
	echo "${SDCARD} --> ${DESTDIR}/${PINAME}_${CURTIME}.img"
	dcfldd bs=32M if="${SDCARD}" of="${DESTDIR}/${PINAME}_${CURTIME}.img"	| tee -a  "${DESTDIR}/${PINAME}_${CURTIME}.log"
	DONETIME=`date +\%F_\%T | sed s/:/\./g`
	echo "Finished ${DONETIME}." | tee -a "${DESTDIR}/${PINAME}_${CURTIME}.log"
else
	echo "Quitting."
fi
