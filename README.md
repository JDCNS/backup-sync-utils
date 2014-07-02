backup-sync-utils
=================

Got tired of standard fare for backing up and, in particular, sync'ing, so
I rolled my own.

This is a combination of tools that I merged from some Raspberry Pi (Raspbian)
and Ubuntu utilities.

Originally, I was using FreeFileSync on Ubuntu, but I have a 32 bit system,
and it seems the maintainers do not have resources and/or time for 32 bit 
systems any longer.  Naturally, I did not set out to reinvent the wheel, but I 
just plain could not get it to compile.  So, I got tired and begain rolling my 
own solution.  Rsync was a utiity I was somewhat familiar with, so there's
where I started.

Meanwhile, I got myself a R-Pi (yay!).  I was using some SD card backup 
utilities (on GitHub, no less) to do the backups, but I had way too many 
issues.  Of course, the entire notion of just how reliable it is to depend 
upon dd on a mounted system was always in the back of my mind, but I never 
really had a chance to test that very thoroughly.  Using 'dd' only worked 
about 30% of the time on a good day.  I think the memory constraints were more
than it could take.  I finally realized that:
1. I really only need one backup of the actual card, as only one partition is 
going to change, and
2. I was already writing a mirroring script for Ubuntu, as per above.  Why not 
use that instead?

So, here we are.  Since I post various things occasionally to my blog, this 
actually addresses yet another lesser issue in that it will be easier to track 
and update.

And, I get to play with the GitHub tool! :)

These are either shell or bash scripts (sorry for the inconsistency, but I 
don't want to mess with what is working -- at least just yet).  The sync 
scripts require rsync.  The SD card scripts require dcfldd, an enhanced 'dd' 
"with forensics".  Actually, I just like the fact that it gives you some idea 
of how far along it is without a lot of process gymnastics.

The sync scripts also use 'notify-send', which will give an error on the Pi 
(it isn't a command).  One work-around is to create an alias for it to use 
printf or echo instead.  I'll leave that up to you.  The error is pretty 
harnless, and if it is running in the background via cron, then it doesn't 
matter all that much anyhow.

The scripts:

mirrordirs.sh -- The original script, renamed from 'syncdirs.sh', does a 
one-way mirror.  Optionally, it does a destructive mirror, performs backups of
deleted files (via the rsync backup), and the nice-ness can be set on the 
commandline.

mysync.sh -- A more enhanced script that tries to do a two-way mirror.  It 
will build a list of files and compare it against the last run to see what 
files have been removed.  Those files will be backed up into a specific 
directory before rsync is run.  This function is what takes most of the script
and, except on very volatile directories or first runs, will often take the 
longest. Configuration and work files are placed in ~/.mysync, including the 
.ignore and .destroy files, which govern what gets ignored or not.  Be careful
about the .destroy files!  By definition, destructive syncs will remove 
anything that is to be ignored!  Always, always, always double-check these 
files before doing a destructive 2-way sync, for there is no recovery after 
the fact (honestly, I don't find the destructive two-way sync as useful as I 
once imagined it might be).

IMPORTANT NOTE:  I stress "two-way"!  It is not a very sophisticated script as
far as that goes, and a three-way sync will definitely confuse it.  There is a
work-around, and that is to create a symbolic link with a different directory 
name for the source's base directory name.  For example, if the final 
directory name in the tree is "bin", then create a symbolic link to bin called
"pibin" for additional runs.  Kludgy, but it works for me.

ANOTHER IMPORTANT NOTE:  You can lose a lot of data if things go wrong.  Every
effort has been made to check to see if shares are mounted.  You will need to 
create a file called "mounted" in the source and destination base directories
(not required in the subdirectories of the tree to sync).  If it did not do 
this, it would see that nothing exists on the one side, and guess what that 
would be interpreted as?  You guessed it, it would be seen as though all the 
files had been removed!  Obviously, that would not be good for large 
directories with lots of data.  In theory, once it has begun any operations, 
a network loss in connectivity would crash the script, but that is not defined
behavior!  It is a theory, not a tested item!

backupsdcard.sh -- Backs up an SD card to a given directory.  Some things are 
assumed, but most of them are changeable through the prompts that follow.

restoresdcard.sh -- does the opposite of backupsdcard.sh.

