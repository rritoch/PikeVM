#!/bin/bash
# Start PikeVM
#

# Change the path below to the location of your pike executable, if not in $PATH
PIKEBIN="pike"
PIKEINCDIR="/usr/local/pike/7.8.700/lib/include"
PIKEMODDIR="/usr/local/pike/7.8.700/lib/modules"

##
## Do not edit below this point unless you know what you are doing
##

ORIGDIR=`pwd`
BOOTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $ORIGDIR

PIKEMASTER="${BOOTDIR}/master-1.1.pike"
PIKESYS="${BOOTDIR}/system-1.1"
PIKELOGERR="${BOOTDIR}/../../var/logs/error.log"

$PIKEBIN -m $PIKEMASTER $PIKESYS -I $PIKEINCDIR -M $PIKEMODDIR

