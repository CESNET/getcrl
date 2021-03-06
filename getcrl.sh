#!/bin/bash
# $Id$

PATH=/bin:/usr/bin

usage="usage: $0 [-s] URL
    -s:		Log the message to standard error, as well as the system log
"

###
# config
###

CRTDIR='/tmp/certs'
CRLDIR='/tmp/certs/'
pri='notice'

logger='/usr/bin/logger'
cut='/usr/bin/cut'
tr='/usr/bin/tr'
ldapsearch='/usr/bin/ldapsearch'
wget='/usr/bin/wget'
openssl='/usr/bin/openssl'
mktemp='/bin/mktemp'
rm='/bin/rm'
cp='/bin/cp'
grep='/bin/grep'
date='/bin/date'
date_mode='linux'
expr='/usr/bin/expr'
ls='/bin/ls'
test='/usr/bin/test'

tag='getcrl'
DEBUG=0

## ERRSTAT values
eSUCCESS=0
eOPT=1
eLOCALENV=2
eGET=3
eREAD=4
eVERIFY=5
eWRITE=6

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
    if $test $DEBUG -gt 0 
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

function getlines() {
    local l
    local ret

    while read l
    do
	ret="$ret\n$l"
    done
    eval "$1=\"$ret\""
}

function get_ldap_url() {
    local rc
    local base
    local tmp
    local url
    local attrs
    local attrlist
    local tmpfile

    if $test "x$ldapsearch" = "x" 
    then
	die $eGET "LDAP URLs not supported. Re-configure the package"
    fi
    attrs=`echo "$1" | $cut -d? -f2`
    attrlist=`echo "$attrs" | $tr ',' ' '`
    tmp=`echo "$1" | $cut -d? -f1`
    url=`echo "$tmp" | $cut -d/ -f-3`
    base=`echo "$tmp" | $cut -d/ -f4`

    OUT=`$ldapsearch -LLL -t -T $WDIR -x -H "$url" -b"$base" '(objectclass=*)' $attrlist 2>&1 >/dev/null`
    rc=$?
    if $test $rc -ne 0 
    then
	$test -n "$OUT" && msg "$OUT"
	ERRSTAT=$eGET
	return $rc
    fi
# || die 1 "ldapsearch $1: $?"

    tmpfile=`($ls $WDIR | $grep ^ldapsearch)` 2>&1
# || die 1 "ldapsearch $1: no crl fetched"
    rc=$?
    if $test $rc -ne 0 
    then
	$test -n "$tmpfile" && msg "$tmpfile"
	ERRSTAT=$eGET
	return $rc
    fi
    echo "$WDIR/$tmpfile"
    return $rc
#    openssl crl -inform DER -in "$WDIR/$tmpfile" -out $WDIR/crl.pem || exit 1
}

function get_wget_url() {
    local rc
    
    OUT=`$wget -q -O $WDIR/crl "$1"`
    rc=$?
    if $test $rc -ne 0 
    then
	$test -n "$OUT" && msg "$OUT"
	ERRSTAT=$eGET
    fi
    echo "$WDIR/crl"
    return $rc
}

function get_url() {
    local rc
    local crlfile

    if echo "$1" | $grep ^ldap: >/dev/null
    then
	crlfile=`get_ldap_url "$1"`
	rc=$?
    else
	crlfile=`get_wget_url "$1"`
	rc=$?
    fi
    if $test $rc -ne 0 -o -z "$crlfile" 
    then
	ERRSTAT=$eGET
	return 1
    fi
    if $grep -e '-----BEGIN .*CRL' $crlfile >/dev/null
    then
	OUT=`$openssl crl -in $crlfile -out $WDIR/crl.pem 2>&1`
	rc=$?
    else
	OUT=`$openssl crl -inform DER -in $crlfile -out $WDIR/crl.pem 2>&1`
	rc=$?
    fi
    if $test $rc -ne 0 
    then
	$test -n "$OUT" && msg "$OUT"
	ERRSTAT=$eGET
    fi
    return $rc
}

function str2num() {
    $expr "$1" + 0
}

function date2iso() {
    local rc

    # Linux: date +%Y%m%d%H%M%S -d "$1"
    # BSD:   date -j -f '%b %d %T %Y %Z' '+%Y%m%d%H%M%S' '$1'

    case $date_mode in
      bsd)
        OUT=`$date -j -f '%b %d %T %Y %Z' '+%Y%m%d%H%M%S' "$1"`;
        ;;
      linux)
        OUT=`date +%Y%m%d%H%M%S -d "$1"`;
        ;;
    esac

    rc=$?
    if $test $rc -ne 0
    then
	 $test -n "$OUT" && msg "$OUT"
    else
	echo "$OUT"
    fi
    return $rc
}

function date2iso_old() {
    local MON
    local day
    local yr
    local hr
    local min
    local sec
    local MONTHS
    local -a MONTHS
    MONTHS=("Jan"  "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    local mon

    MON=`echo "$1" | $cut -d' ' -f1`
    day=`echo "$1" | $cut -b5-6`
    hr=`echo "$1" | $cut -b8-9`
    min=`echo "$1" | $cut -b11-12`
    sec=`echo "$1" | $cut -b14-15`
    yr=`echo "$1" | $cut -b17-20`
    # fix the month
    
    mon=0
    while $test $mon -lt 12 
    do
	if eval "$test \"$MON\" = \"${MONTHS[$mon]}\""
	then
	    break
	fi
	mon=`expr $mon + 1`
    done
    mon=`expr $mon + 1`

    mon=`str2num $mon`
    day=`str2num $day`
    hr=`str2num $hr`
    min=`str2num $min`
    sec=`str2num $sec`
    yr=`str2num $yr`
    printf "%.4d%.2d%.2d%.2d%.2d%.2d" $yr $mon $day $hr $min $sec
}

# function crl_fix_ldap() {
#     local attr
#     attr=`echo $url | cut -d? -f2`
#     val=`cat $WDIR/crl | grep -vi ^dn: | sed -e "/$attr/I s/[ \t]*$attr\(;binary\)\?: //I;"`
#     echo "$val" | openssl crl -inform DER 
# }

### Start the work
###
# PHASE 1 - getting the commands
###
syslog_s="-s"			# let's talk to stderr initially
ERRSTAT=$eOPT			# error exit status for the first phase

# get params
TEMP=`getopt s $*`
if $test $? -ne 0 
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

# The last arg is the URL
url="$1"
$test -n "$url" || die $ERRSTAT "$usage"
syslog_s="$OPT_s"		# go for user choice of logging

msg "Starting with $url"

WDIR=`$mktemp -dt getcrl.XXXXXX` || exit 1
trap  "$rm -rf $WDIR" EXIT

ERRSTAT=$eGET
get_url "$url" || die $ERRSTAT "Error downloading the CRL. Exiting."

### get the hash
ERRSTAT=$eREAD
HASH=`$openssl crl -out /dev/null -hash -in $WDIR/crl.pem 2>&1`
if $test $? -ne 0 
then
    $test -n "$HASH" && msg "$HASH"
    die $ERRSTAT "Error getting CRL hash. Exiting."
fi
dbg $HASH

### verify the CRL
ERRSTAT=$eVERIFY
OUT=`$openssl crl -out /dev/null -CApath $CRTDIR -in $WDIR/crl.pem 2>&1`
if $test $? -ne 0 
then
    $test -n "$OUT" && msg "$OUT";
    die $ERRSTAT "CRL verification error. Exiting."
fi

### get the new update
ERRSTAT=$eREAD
nupdatestr=`$openssl crl -lastupdate -out /dev/null -in $WDIR/crl.pem | $cut -d= -f2` || die $ERRSTAT "Error reading lastupdate from new CRL"

nupdate=`date2iso "$nupdatestr"`

### find the old crl
ERRSTAT=$eWRITE
if $test ! -e $CRLDIR/$HASH.r0 
then
    oupdate='00000000000000'
else
    oupdatestr=`$openssl crl -lastupdate -out /dev/null -in $CRLDIR/$HASH.r0 | $cut -d= -f2` || die $eREAD "Error reading lastupdate from old CRL. Exiting."
    ### get the old update
    oupdate=`date2iso "$oupdatestr"`
fi

### are we younger?
if $test $nupdate -gt $oupdate 
then
    msg "New CRL is younger than the installed one."
    OUT=`$cp $WDIR/crl.pem $CRLDIR/$HASH.r0 2>&1`
    if $test $? -ne 0 
    then
	die $cWRITE "CRL installation error. Exiting"
    fi
else
    msg "New CRL is not younger than the installed one. Skipping."
fi
die $eSUCCESS "Task completed."
