#!/bin/bash
# Start PikeVM
#

# Change the path below to the location of your pike eecutable
PIKEBIN="/usr/local/pike/7.8.700/bin/pike"


##
## Do not edit below this point unless you know what you are doing
##

ORIGDIR=`pwd`
BOOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $ORIGDIR

PIKEMASTER="${BOOTDIR}/master-1.0.pike"
PIKESYS="${BOOTDIR}/system-1.0"
PIKELOGERR="${BOOTDIR}/error.log"

$PIKEBIN -m $PIKEMASTER $PIKESYS

