#!/bin/sh
#
# mirrordirs (originally called syncdirs b/c it is based on rsync)
#
# create duplicate of source directory in destination directory (or,
# if using file backup, in root subdirectory of destination directory).
#
# Copyright 2014(c) by John D Carmack, John D's Computer Services;
# No warranty, no guarantee; software may spontaneously combust,
# irradiate your gerbil, entice the bird of paradise to fly up your
# nose or even destroy all data on all drives everywhere simultaneously.
# Seriously, though, there is no warranty, and the only guarantee is
# that if you don't know what you are doing, you will lose data.
#
# Governed by MIT License, (http://opensource.org/licenses/mit-license.php)
# specifically:
#
# "Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the “Software”), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# "The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software."
#
# This program was originally written to do a destructive mirror from the 
# source directory to the destination.  I eventually made the destructive part
# optional, as I was trying to incorporate other functionality that wound up 
# being a different script entirely.  The "nice" feature was added because 
# left unchecked, doing rsync over a network can really bog down the source
# machine.
#
# Lastly, I added code to create a backup of deleted files, as I extended the
# capability to fit my needs on the Raspberry Pi, which would be a one-way
# sync.
#
# It should be stressed that this program is excellent for a one-way sync, but
# for a two-way sync, not so much.  That is why I created the other script,
# mysync.sh.
#

usage()
{
	echo "Usage: $THISPROG [-d] [-b] [-q] [-x] [-n x] sourcedir destdir"
	echo "Where: -d means delete excluded files"
	echo "       -b means to put files in destdir/root and backup files into"
	echo "           destdir/backup"
	echo "       -q means quiet, don't prompt to continue (REQUIRES '-b!]"
	echo "       -x means don't cross file systems (no mount points)"
	echo "       -n x, where x is the nice level"
	echo "       sourcedir and destdir MUST be directories!"
	exit 1
}

# Sometimes, you need to be paranoid :)
THISPROG="$0"

NICE="10"
DOBACKUP="0"
SUPPRESSPROCEEDPROMPT="0"
SHOWPROGRESS="--progress"
EXCLUDEMOUNTPOINTS=" "
# Assume update (skip newer files on receiving end) unless deleting
DEL="-u"

while getopts "bdqxn:" o; do
	case "${o}" in
		b)
			DOBACKUP="1"
			;;
		d)
			DEL="--delete-before --delete-excluded"
			;;
		n)
			NICE=${OPTARG}
			;;
		q)
			SUPPRESSPROCEEDPROMPT="1"
			SHOWPROGRESS=" "

			;;
		x)
			EXCLUDEMOUNTPOINTS="-x"
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))


if [ "$#" -lt "2" ]
then
	usage
fi

ORIGDIR="$1"
DESTDIR="$2"
echo "$ORIGDIR" | grep "/$" > /dev/null
if [ "$?" = "1" ]
then
	ORIGDIR="$ORIGDIR/"
fi
echo "$DESTDIR" | grep "/$" > /dev/null
if [ "$?" = "1" ]
then
	DESTDIR="$DESTDIR/"
fi

CURTIME=`date +\%F_\%T | sed s/:/\./g`
echo "Time $THISPROG began $CURTIME"

if [ "$DOBACKUP" = "1" ]
then
	DESTDIRROOT="${DESTDIR}root"
	DESTDIRBACKUP="${DESTDIR}backup"
	BACKUPCMD="-b --backup-dir=${DESTDIRBACKUP} --suffix=.${CURTIME}"
else
	DESTDIRROOT="${DESTDIR}"
	BACKUPCMD=" "
fi

echo $ORIGDIR "->" $DESTDIR
echo "$DEL" "$EXCLUDEMOUNTPOINTS"
echo "BACKUPCMD = ${BACKUPCMD}"
echo "nice level $NICE"

# First, check for destination directory
if [ -d "$DESTDIR" ] && [ -d "$ORIGDIR" ]
then
	if [ "$SUPPRESSPROCEEDPROMPT" = "1" ]
	then
		if [ "$DOBACKUP" = "0" ]
		then
			echo "Error! Must do backup if suppressing prompt!"
			exit 4
		else
			YN="Y"
		fi
	else
		echo -n "Proceed [Y/n]? "
		read YN
		if [ "$YN" = "" ]
		then
			YN="Y"
		fi
	fi
	if [ "$YN" = "y" -o "$YN" = "Y" ]
	then
	# Filter rules are a bit confusing ... edited excerpt from man page:
	# a '*' matches any path component, but it stops at slashes.
	# use '**' to match anything, including slashes.
	# if the pattern contains a / (not counting a trailing /) or a "**",
	# then it is matched against the full pathname, including any leading
	# directories. If the pattern doesn't contain a / or a "**", then it
	# is matched only against the final component of the filename. (Remember
	# that the algorithm is applied recursively so "full filename" can
	# actually be any portion of a path from the starting directory on down.)

		if [ "$DOBACKUP" = "1" ]
		then
			if [ ! -d $DESTDIRROOT ]
			then
				mkdir $DESTDIRROOT
			fi
			if [ ! -d $DESTDIRBACKUP ]
			then
				mkdir $DESTDIRBACKUP
			fi
		fi

		nice -n $NICE rsync -va $SHOWPROGRESS $EXCLUDEMOUNTPOINTS $DEL --exclude=**~ --exclude=**/*cache*/ --exclude=**/*Cache*/ --exclude=Thumbs.db --exclude=**.ffs_db --exclude=.local/share/Trash --exclude=.Trash-* --exclude=*.Sync* --exclude=**Desktop.ini --exclude=**desktop.ini --exclude=**/*_vti_cnf*/ --exclude=**\!sync $BACKUPCMD "$ORIGDIR" "$DESTDIRROOT"
		echo "Done!"
	else
		echo "Aborted!"
	fi
else
	notify-send 'Sync Failed' 'Please connect hard drive or mount share and check ASAP!'
fi

CURTIME=`date +\%F_\%T | sed s/:/\./g`
echo "Time $THISPROG ended $CURTIME"

