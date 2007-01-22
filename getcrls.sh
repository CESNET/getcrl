#!/bin/bash
# $Id$
#
# Sample script for installing multiple CRLs. It expects the list of URLs
# from which the CRLs should be downloaded in a file passed as the 
# script parameter. The file should contain one URL on each line.
# Comments in the shell syntax (#- end of line) may be included.

PATH=/bin:/usr/bin

usage="usage: $0 [-s] [file]
    -s:		Log the message to standard error, as well as the system log
    file:	File with one CRL URL by line. Defaults to $CFGDIR/getcrls.cfg
"
###
# config
###
CFGDIR="."
SBINDIR="."
tag='getcrls'
pri='notice'

getcrl="$SBINDIR/getcrl.sh"

logger='/usr/bin/logger'
cut='/usr/bin/cut'
sed='/bin/sed'

eSUSSCESS=0
eOPT=1
eRUN=2

function msg() {
#    if [ "$syslog" ]
#    then
	$logger $syslog_s -t "$tag[$$]" -p daemon.$pri "$*"
#    else
#	echo -e "$*" >&2
#    fi
}

function dbg() {
    local opri=$pri
    if [ $DEBUG -gt 0 ]
    then
	pri='debug'
	msg "$*"
	pri=$opri
    fi
}

function die() {
    local status="$1"
    local opri=$pri
    shift
    pri='err'
    msg "$*"
    exit $status
}


###
# PHASE 1 - getting the commands
###
syslog_s="-s"			# let's talk to stderr initially
ERRSTAT=$eOPT			# error exit status for the first phase

# get params
TEMP=`getopt s $*`
if [ $? -ne 0 ]
then
    die $ERRSTAT "$usage
Terminating..."
fi
eval set -- "$TEMP"
while true
do
    case "$1" in
	-s) OPT_s='-s'; shift;;
	--) shift; break;;
	*)  die $ERRSTAT "Internal error";;
    esac
done

CRLList="$1"
test -n "$CRLList" || CRLList="$CFGDIR/getcrls.cfg"
test -r "$CRLList" || die $ERRSTAT "$CRLList not readable"

syslog_s="$OPT_s"		# go for user choice of logging
ERRSTAT=$eRUN

while read crl
do
    crl=`echo "$crl" | $cut -d\# -f1 | $sed -e 's/^[ 	]*//; s/[ \t]*$//'`
    if [ -n "$crl" ]
    then
	$getcrl $OPT_s "$crl"
    fi
done < "$CRLList"
