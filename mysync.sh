#!/bin/bash
#
# Input 2 directories, first source, second destination.
# Do compare and see which have been removed from source and remove from
# destination by moving it to hold directory.
#
# mysync, two-way sync based on rsync
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
# This program was originally written to replace two-way sync program
# FreeFileSync.  Originally, I was going to call syncdirs/mirrorsync as
# part of the process but drop the destructive part, but that actually
# made it more complicated.
#
# Note that because it was originally a one-way sync, "source" and "dest"
# are loosely used.  What is important is that one side be designated
# the "source", one side be designated the "destination", and that neither
# change.  Calling it backwards could ruin your day.
#
# First, it creates file lists of source and compares contents to last run
# (if there were any) to see if any files have been removed.  If so,
# backup files into special ubackups directory.  Repeat for destination.
# Then, run rsync nondestructive from source to destination, then update
# file listing of destination.  Repeat for destination to source.
#
# Since initially written, the changes have been far and few between.
# A lot of the tweaks have been in logging various messages, and
# there are a lot of messages.  Care should be made to backup and
# trim logs occasionally.
#
# However, the majority of the important tweaks have been in the files
# that control ignored files and directories.  They follow the rsync
# documentation, but <basedirectory>.ignore is used for normal two-way
# sync, wherease <basedirectory>.destory is used for the destructive
# two-way sync.  Personally, I don't use the destructive two-way sync,
# and it is fairly dangerous to use.  If a file is ignored in this script,
# and --delete-before is called, then it will delete the file.  Perhaps
# worse, if a file is added to the destination, then it will be removed
# because it does not exist in the source.
#
# I advise using mirrordirs instead if you want a destructive script.
# It was originally put in here because the original intent was to have
# one script that did it all, or at very least one script that calls
# the other.  At very least, if mirrordirs removes files, it is only on
# one side rather than both, unless of course you re-run it the other
# direction.
#
# You have been warned.

# Save off because I'm paranoid
THISPROG="$0"

if [ "$HOME." == "." ]
then
    echo "FATAL ERROR: HOME environment variable not set!"
    notify-send "$THISPROG Failed" 'HOME not specified!'
    exit 2
fi

# This should be changed if run as sudo user!  Why would you need
# to, though?  This was once necessary, but probably not needed now.
export PATH=${HOME}/bin:/usr/lib/lightdm/lightdm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$PATH

usage()
{
	printf "Usage: $THISPROG [-d] [-n x] sourcedir destdir \nWhere: -d means delete excluded files \n       -n x, where x is the nice level \n       sourcedir and destdir MUST be directories!\n\n" 1>&2
	exit 1
}

NICE="10"
DESTROYFLAG="0"
CURTIME=`date +\%F_\%T | sed s/:/\./g`

while getopts "dn:" o; do
	case "${o}" in
		d)
			DESTROYFLAG="1"
			;;
		n)
			NICE=${OPTARG}
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

SRCDIR="$1"
DESTDIR="$2"
# See if last character is '/'
echo "$SRCDIR" | grep "[^/]$"
if [ $? -eq 0 ]
then
    # Last character not '/', which is good
    echo "Ok."
else
    # Remove last character because we need only name,
    # else we wind up with all sorts of issues later
    SRCDIR=`echo "$SRCDIR" | sed s'/.$//'`
    echo "Dropped trailing slash"
fi
echo "SRCDIR is $SRCDIR"
# Same for destdir
echo "$DESTDIR" | grep "[^/]$"
if [ $? -eq 0 ]
then
    echo "Ok."
else
    DESTDIR=`echo "$DESTDIR" | sed s'/.$//'`
    echo "Dropped trailing slash"
fi
echo "DESTDIR is $DESTDIR"

# It is one thing if the destination exists, but what if it is a share that isn't mounted?
# Then life gets more complicated.  Better safe than sorry.
if [ -f "$DESTDIR/mounted" ] && [ -f "$SRCDIR/mounted" ]
then
	echo "SRCDIR and DESTDIR OK"
else
	if [ ! -f "$DESTDIR/mounted" ]
	then
		echo "Destination/mounted does not exist!"
	fi
	if [ ! -f "$SRCDIR/mounted" ]
	then
		echo "Source/mounted does not exist!"
	fi

	notify-send 'Sync Failed' 'Please connect  and/or mount drive and check ASAP!'
	exit 3
fi

CONFIGDIR="$HOME/.mysync"
BACKUPDIR="$HOME/ubackups"
# Make sure they exist!
if [ ! -d "$CONFIGDIR" ]
then
    mkdir -p "$CONFIGDIR"
fi
if [ ! -d "$BACKUPDIR" ]
then
    mkdir -p "$BACKUPDIR"
fi

# Get basename of directory for config files
# Neat trick I found on the net: Reverse string then use cut and reverse back
# guarantees getting last field no matter how many
BASEDIR=`echo "$SRCDIR" | rev | cut -d '/' -f1 | rev`
BASEDIRIGNOREFILE="$CONFIGDIR/$BASEDIR.ignore"
BASEDIRDESTROYFILE="$CONFIGDIR/$BASEDIR.destroy"
LOGFILE="$CONFIGDIR/$BASEDIR.log"
echo "Logging to $LOGFILE" | tee -a "$LOGFILE"
echo "Sync begins $CURTIME" | tee -a "$LOGFILE"

# Debug
# echo $CONFIGDIR $BACKUPDIR $SRCDIR $DESTDIR $BASEDIR
# exit 0

# If basedir temp file exists, assume last run crashed
if [ -f "$CONFIGDIR/$BASEDIR.tmp" ]
then
    rm "$CONFIGDIR/$BASEDIR.tmp"
    LASTCRASHED=1
else
    LASTCRASHED=0
fi

NUMFILES=`find "$CONFIGDIR/$BASEDIR"_SRC.* -type f | wc -l`

if [[ "$NUMFILES" > "4" ]]
then
    NUMFILES=`expr $NUMFILES - 1`

    if [ "$LASTCRASHED" == "0" ]
    then
        for ((JJ=0;JJ<$NUMFILES;JJ++))
        do
            KK=`expr $JJ + 1`
            cp "$CONFIGDIR"/"$BASEDIR"_SRC."$KK" "$CONFIGDIR"/"$BASEDIR"_SRC."$JJ" | tee -a "$LOGFILE"
            cp "$CONFIGDIR"/"$BASEDIR"_DEST."$KK" "$CONFIGDIR"/"$BASEDIR"_DEST."$JJ" | tee -a "$LOGFILE"
        done
        rm "$CONFIGDIR"/"$BASEDIR"_SRC."$NUMFILES" | tee -a "$LOGFILE"
        rm "$CONFIGDIR"/"$BASEDIR"_DEST."$NUMFILES" | tee -a "$LOGFILE"
    fi
fi

if [[ "$NUMFILES" < "1" ]]
then
    # Must be first run, assume empty directory
    touch "$CONFIGDIR"/"$BASEDIR"_SRC."$NUMFILES"
    touch "$CONFIGDIR"/"$BASEDIR"_DEST."$NUMFILES"
    NUMFILES=1
fi
LASTFILE=`expr $NUMFILES - 1`

if [ ! -e "$BASEDIRIGNOREFILE" ]
then
    # Create default ignore and destroy files
# -----------------------------------------------
# Begin here document
(
cat <<'EOF'
# Standard ignores
**~
**/*[cC]ache*/
Thumbs.db
**.ffs_db
.local/share/Trash
*.Sync*
**[dD]esktop.ini
**/*_vti_cnf*/
**\!sync
# Excel temp files -- just make them go away!
.~*\#

# Be careful here, these should not be run as part of a "destroy" operation!
.fuse_hidden*
**gvfs**
.vnc
# Seriously, why is Windows so screwed up?
[nN][tT][uU][sS][eE][rR].dat*
.[pP]rivate
.ecryptfs
# Excuse yourself
.mysync
ubackups**
# Backing up Dropbox live directory is redundant and not safe
.[dD]ropbox

# VirtualBox notes -- VB has changed how it works
# Even less safe, Windows and Linux cannot share VBox configs
#\.VirtualBox
# Instead of this, set Windows environment variable VBOX_USER_HOME to
# something like "%HOMEDRIVE%%HOMEPATH%/.config/VirtualBox.windows"
# and in Linux set variable "VBOX_USER_HOME=$HOME/.config/VirtualBox.linux"
# without quotes and replacing $HOME as appropriate in $HOME/.pam_environment

# Additional directives go here
EOF
) > "$BASEDIRIGNOREFILE"
# End here document
# -----------------------------------------------

    # Duplicate to default destroy file
    cp "$BASEDIRIGNOREFILE" "$BASEDIRDESTROYFILE"
fi

if [ "$DESTROYFLAG" = "1" ]
then
    IGNOREFILE="$BASEDIRDESTROYFILE"
else
    IGNOREFILE="$BASEDIRIGNOREFILE"
fi

function createlistfiles {
    # Setup direction
    MAPSIDE=$1
    if [ "$MAPSIDE" == "SRC" ]
    then
        FINDSIDE=$SRCDIR
    elif [ "$MAPSIDE" == "DEST" ]
    then
        FINDSIDE=$DESTDIR
    else
        echo "Error in parm $1!" | tee -a "$LOGFILE"
        exit 1
    fi
    # Debugging
    # echo "$FINDSIDE" "$CONFIGDIR"/"$BASEDIR"_"$MAPSIDE"."$NUMFILES"
    #exit 0

    # Do the work
    echo "Updating file lists $MAPSIDE ..." | tee -a "$LOGFILE"
    # This may seem odd, but if FINDSIDE is a symbolic link, then it needs trailing slash
    find "$FINDSIDE/" -path "*" -print > "$CONFIGDIR"/"$BASEDIR"_"$MAPSIDE"."$NUMFILES"
    # exit 0
}

function createremovedfilelist {
    # Setup direction
    MAPSIDE=$1
    if [ "$MAPSIDE" == "SRC" ]
    then
        FINDSIDE=$SRCDIR
    elif [ "$MAPSIDE" == "DEST" ]
    then
        FINDSIDE=$DESTDIR
    else
        echo "Error in parm $1!" | tee -a "$LOGFILE"
        exit 1
    fi

    # Create tmp file
    echo "Looking for removed files..."
    while read line
    do
	printf "."
        # Sigh, fix square brackets if they exist
        NOSQUARE=`echo "$line" | sed 's/\[/\\\[/g' | sed 's/\]/\\\]/g'` >> /dev/null
        grep "$NOSQUARE$" "$CONFIGDIR/$BASEDIR"_"$MAPSIDE"."$NUMFILES" >> /dev/null
        GRESULT="$?"
        # echo "$GRESULT on $NOSQUARE"
        if [ "$GRESULT" != "0" ]
        then
            # We have a match; log it first
            echo "Found matching removed file '$NOSQUARE'" | tee -a "$LOGFILE"
	    # Assume grep doesn't find it in ignored file until proven otherwise
	    IGNORERESULT="1"
	    while read lineignore
	    do
		# echo "$lineignore." | tee -a "$LOGFILE"
		# Is it only whitespace?
		# ** It honestly DOES NOT seem to matter,
		# for it appears bash compresses it first
#		echo "$lineignore" | grep "(\S*)" >> /dev/null
#		ALLSPACE="$?"
		# echo "ALLSPACE is $ALLSPACE" | tee -a "$LOGFILE"
		# Is it a comment?
		echo "$lineignore" | grep '^\#' >> /dev/null
		BEGINHASH="$?"
		# echo "BEGINHASH is $BEGINHASH" | tee -a "$LOGFILE"
#		if [ "$ALLSPACE" != "0" ] && [ "$BEGINHASH" != "0" ] && [ "$lineignore" != "" ]
		if [ "$BEGINHASH" != "0" ] && [ "$lineignore" != "" ]
		then
			echo "$NOSQUARE" | grep "$lineignore" >> /dev/null
        	        IGNORERESULT="$?"
			# If found in the ignored file, then exit while loop
	                if [ "$IGNORERESULT" = "0" ]
	                then
			    echo "$NOSQUARE is an ignored file because of '$lineignore'." | tee -a "$LOGFILE"
			    break
		        fi
		fi
	    done < "$IGNOREFILE"
	    if [ "$IGNORERESULT" != "0" ]
	    then
                 echo "Adding '$NOSQUARE' to '$CONFIGDIR/$BASEDIR'.tmp" | tee -a "$LOGFILE"
                 echo "$NOSQUARE" >> "$CONFIGDIR/$BASEDIR".tmp
	    fi

# exit 0
        fi
    done < "$CONFIGDIR/$BASEDIR"_"$MAPSIDE"."$LASTFILE"
    printf "\n"
#    exit 0
}

function archivedeletedfiles {
    # Save off direction
    MAPSIDE="$1"
    # See if file even exists first, else waste of time
    if [ -f "$CONFIGDIR/$BASEDIR.tmp" ]
    then
        # Set direction
        if [ "$MAPSIDE" == "SRC" ]
        then
            SRCSIDE="$SRCDIR"
            DESTSIDE="$DESTDIR"
        elif [ "$MAPSIDE" == "DEST" ]
        then
            SRCSIDE="$DESTDIR"
            DESTSIDE="$SRCDIR"
        else
            echo "Error in archivedeleted files function parm $1!" | tee -a "$LOGFILE"
            exit 1
        fi

        # Do the work
        echo "Archiving removed files ..." | tee -a "$LOGFILE"
        while read line
        do
	    # Outlier case
	    if [ "$line" == "$SRCSIDE" ]
	    then
		echo "Ignoring base directory $line" | tee -a "$LOGFILE"
	    else
	        DESTFULLNAME=`echo $line | sed s,"$SRCSIDE","$DESTSIDE",`
        	if [ -e "$DESTFULLNAME" ]
            	then
			FULLBACKUPFILE="${BACKUPDIR}/${BASEDIR}.${MAPSIDE}_${CURTIME}${DESTFULLNAME}"
			echo "Full BACKUPFILE in $FULLBACKUPFILE" | tee -a "$LOGFILE" >&2
			FULLBACKUPDIR=`dirname "${FULLBACKUPFILE}"`
			if [ -d "${FULLBACKUPDIR}" ]
			then
				echo "${FULLBACKUPDIR} exists. OK."> >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2)
			else
				echo "${FULLBACKUPDIR} does not exist. Attempting to create."
				mkdir -p "${FULLBACKUPDIR}"> >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2)
			fi
                	# We want screen output as well as logfile output here,
                	# so do some redirect wizardry
                	mv -v "$DESTFULLNAME" "$FULLBACKUPFILE" > >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2)
            	else
                	# We have a name, but no file. Maybe already moved?
                	# In any event, log it.
                	echo "$DESTFULLNAME does not exist -- skipping ..." | tee -a "$LOGFILE"
            	fi
	    fi
        done < "$CONFIGDIR/$BASEDIR.tmp"
        rm "$CONFIGDIR/$BASEDIR.tmp"
    fi
}

function dorsync {
#    DRYRUNFLAG=1
    if [ $DRYRUNFLAG ]
    then
        DRYRUNSTRING="--dry-run"
    else
        # Cannot use space, as rsync trips up on it
        DRYRUNSTRING="-u"
    fi
    if [ "$DESTROYFLAG" = "1" ]
    then
        DELETESTRING="--delete-excluded"
    else
        # Have to specify something, might as well be something that makes sense.
        DELETESTRING="--safe-links"
    fi

    # Final Sanity check
    if [ -f "$1/mounted" ] && [ -f "$2/mounted" ]
    then
        echo "flags: $DRYRUNSTRING" "$DELETESTRING" "$IGNOREFILE" "$1/" "$2/" | tee -a "$LOGFILE"
        nice -n $NICE rsync -vurptD "$DRYRUNSTRING" "$DELETESTRING" --exclude-from="$IGNOREFILE" "$1/" "$2/" > >(tee -a "$LOGFILE") 2> >(tee -a "$LOGFILE" >&2)
        echo "Rsync $1 -> $2 Done!"
    else
	echo "Error in either source dir $1 or dest dir $2!" | tee -a "$LOGFILE"
	notify-send 'Sync Failed' 'Please connect hard drive and back up your daturz ASAP!'
	exit 3
    fi
}

# Find out what files have been deleted from source; store in temp file.
createlistfiles SRC
createremovedfilelist SRC
# We now have list, so let's remove them from destination.
archivedeletedfiles SRC

# Now do same for destination
createlistfiles DEST
createremovedfilelist DEST
archivedeletedfiles DEST

# Now do an rsync
dorsync "$SRCDIR" "$DESTDIR"
# Guess what? We are now out of date already!
createlistfiles DEST
# Now do in reverse
dorsync "$DESTDIR" "$SRCDIR"
createlistfiles SRC
# Final cleanup
rm "$CONFIGDIR/$BASEDIR.tmp" &> /dev/null
CURTIME=`date +\%F_\%T | sed s/:/\./g`
echo "Sync finished $CURTIME" | tee -a "$LOGFILE"
echo " " | tee -a "$LOGFILE"

# Note to self: Don't forget double quotes for variable expansion
notify-send "$THISPROG Completed" "Check $LOGFILE for details"

