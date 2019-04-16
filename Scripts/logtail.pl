#!/usr/bin/perl -w
# Output of the part of the log file added since the last run of the script

use strict;
use Getopt::Long;


# Hash command line options
my %Opts = ();
# Command line processing
GetOptions(\%Opts, 'logfile=s', 'offset=s');
$Opts{logfile} and $Opts{offset} or
 print(STDERR "Error: parameters --logfile=log --offset=offset\n") and
 exit(66);

# Open log file, log file number and size
open(LOGFILE, $Opts{logfile}) and my($ino, $size) = (stat($Opts{logfile}))[1, 7]
 or print(STDERR "Error: opening file '$Opts{logfile}'\n") and exit 66;

# Getting the number of the log file and the offset in it from the offset file
my($inode, $offset);
open(OFFSET, $Opts{offset}) and $_ = <OFFSET> and close(OFFSET) and
 ($inode, $offset) = /^(\d+)\t(\d+)$/ or ($inode, $offset) = (0, 0);

# Log file number has not changed
if($inode == $ino){
 # Log file has not changed - exit
 $offset == $size and exit(0);
 # Offset less than the size of the log file and position in the log file - offset
 # or similar to the first launch
 $offset < $size and seek(LOGFILE, $offset, 0) or $inode = 0;
}

# Saved log file number - start is not first
if($inode){
 # Show log lines
 while(<LOGFILE>){ print $_; }
 # Offset in log file after last line
 $size = tell(LOGFILE);
}
# Close log file
close(LOGFILE);

# Store the number and offset of the log file in the offset file
open(OFFSET, ">$Opts{offset}") and print(OFFSET "$ino\t$size") and close(OFFSET)
 or print(STDERR "Error: $Opts{offset} offset file\n") and exit(73);

exit 0;
