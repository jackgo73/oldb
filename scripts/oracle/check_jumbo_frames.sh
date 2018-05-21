#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_jumbo_frames.sh /main/6 2013/10/21 06:50:12 fjlee Exp $
#
# check_jumbo_frames.sh
#
# Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      check_jumbo_frames.sh - Jumbo frames configuration for interconnect
#
#    DESCRIPTION
#      Script to check jumbo frames configuration for interconnect
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    fjlee       09/27/13 - bug 17500747
#    dsaggi      08/29/13 - XbranchMerge dsaggi_bug-17309882 from st_has_11.2.0
#    nvira       10/10/12 - bug fix 14364702
#    nvira       06/06/12 - fix message
#    nvira       08/25/10 - pluggable task script to check jumbo frame settings
#    nvira       08/25/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/etc

SGREP="grep"
SAWK="awk"
SCUT="cut"
SNETSTAT="netstat"
SUNIQ="uniq"
STAIL="tail"
SSED="sed"
SIFCONFIG="ifconfig"
SNWMGR="nwmgr"

#returns list of all interfaces
listOfInterfaces()
{
  INTERFACE_LIST=`$SNETSTAT -i | $SSED '1d' | cut -d ' ' -f 1 | cut -d ':' -f 1 | sort -u`
}

#expand list of interfaces for any wildcard characters 
expandInterfaces()
{
  ARG=$1
  EXPANDED_LIST=`echo $INTERFACE_LIST| $SAWK '{gsub(" ","\n", $0); print}' | $SSED "s/$/ $ARG/" | $SAWK '{if ($1 ~ $2) print $1 }'`
}

verifyInterface()
{
interfaceName=$1
#first check if there is any interface specific value defined for the parameter

case $PLATFORM in
  Linux)
      paramValue=`$SIFCONFIG $interfaceName | $SGREP -i mtu | $SCUT -d: -f2| $SAWK '{print \$1}'`
  ;;
  SunOS)
      paramValue=`$SIFCONFIG $interfaceName | $SGREP -i mtu | $SAWK '{print \$4}'`
  ;;
  AIX)
      paramValue=`$SNETSTAT -I $interfaceName | $SSED '1d' | $SAWK '{print \$2}' | $STAIL -1`
  ;;
  HP-UX)
      paramValue=`$SNWMGR -g -A mtu -c $interfaceName | $SSED '1d' | $SAWK '{print \$3}'`
  ;;
esac
ret=$?

if [ $ret -eq 0 ]
then
  if [ $paramValue -eq $expected ]
  then 
    ERROR_CODE=0
  else
    ERROR_CODE=3
  fi   
else
  ERROR_CODE=4
fi   
return $ERROR_CODE
}


PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

CRS_HOME=$1
expected=$2

# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXPECTED>$expected</EXPECTED><EXEC_ERROR>Unable to get the Jumbo Frames setting information on the system</EXEC_ERROR><TRACE>Unable to get the Jumbo Frames setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0294</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"


listOfInterfaces


# ensure that the clusterware stack is up and that the cluster interfaces can be retrieved using oifcfg

interfaceNames=`$CRS_HOME/bin/oifcfg getif | $SGREP cluster_interconnect | $SAWK '{print \$1}'`
ret=$?
if [ $ret -ne 0 -o "X${interfaceNames}" = "X" ]
then
  echo $result
  exit 0
fi
#strip off any new line characters
interfaceNames=`echo $interfaceNames`

#expand any wild cards
expandedList=""
for interfaceName in $interfaceNames; do
  expandInterfaces "$interfaceName"
    expandedList=`echo "$expandedList $EXPANDED_LIST"`
done

expandedList=`echo $expandedList |  $SAWK '{gsub("\n"," ", $0); print}'`


FAILED_INTERFACES=""
FAILED_COLLECTED=""

for interfaceName in $expandedList; do
 verifyInterface "$interfaceName"
 ret=$?
 if [ "X$COLLECTED" != "X" ]
 then
  COLLECTED=`echo "$COLLECTED;"`
 fi
 COLLECTED=`echo "$COLLECTED$interfaceName=$paramValue"`

 if [ $ret -ne 0 ]
 then
   if [ "X$FAILED_INTERFACES" != "X" ]
   then
    FAILED_INTERFACES=`echo "$FAILED_INTERFACES,"`
    FAILED_COLLECTED=`echo "$FAILED_COLLECTED;"`
   fi
   FAILED_INTERFACES=`echo "$FAILED_INTERFACES$interfaceName"`
   FAILED_COLLECTED=`echo "$FAILED_COLLECTED$interfaceName=$paramValue"`
 fi
done

if [ "X$FAILED_INTERFACES" = "X" -a "X$COLLECTED" != "X" ]
then
    result="<RESULT>SUCC</RESULT><COLLECTED>$COLLECTED</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Jumbo frames or mini jumbo frames are configured for interconnect on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0292</ID><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$FAILED_COLLECTED</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Jumbo frames are not configured for interfaces \"$FAILED_INTERFACES\" on node $_HOST.[Expected=$expected; Found=$FAILED_COLLECTED]</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0293</ID><MSG_DATA><DATA>$_HOST</DATA><DATA>$expected</DATA><DATA>$FAILED_COLLECTED</DATA><DATA>$FAILED_INTERFACES</DATA></MSG_DATA></NLS_MSG>"    
fi

echo $result
exit 0
