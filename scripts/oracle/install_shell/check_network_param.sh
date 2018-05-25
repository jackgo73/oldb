#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_network_param.sh /main/10 2013/12/20 07:38:31 xesquive Exp $
#
# check_network_param.sh
#
# Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      check_network_param.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    xesquive    10/22/13 - support unknown interfaces bug 13531839
#    dsaggi      03/25/13 - XbranchMerge dsaggi_bug-16352763 from
#                           st_has_12.1.0.1
#    dsaggi      03/08/13 - Fix 16352763 -- correct operator for comparing
#                           global value
#    nvira       12/13/12 - bug fix 14783811
#    nvira       01/03/12 - bug fix 13531373
#    dsaggi      10/11/11 - fix 13077654 -- change path for no command
#    nvira       08/18/11 - bug fix 12878750
#    nvira       07/19/11 - Backport nvira_bug-12536867 from main
#    nvira       08/25/10 - script to check network parameter
#    nvira       08/11/10 - Creation
#

#returns list of all interfaces
listOfInterfaces()
{
  INTERFACE_LIST=`netstat -i | $SSED '1d' | cut -d ' ' -f 1 | sort -u`
  #echo "INTERFACE_LIST=$INTERFACE_LIST"
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
paramValue=`/etc/ifconfig $interfaceName | $SGREP $paramName | $SSED "s/\(.*\)$paramName \([0-9]*\)\(.*\)/\2/"`

if [ "X$paramValue" != "X" ]
then
  if [ $paramValue -ge $expected ]
  then 
    ERROR_CODE=0
  else
    ERROR_CODE=2
  fi   
  return $ERROR_CODE
fi

#else check the global value defined for the parameter
paramValue=`$NO -o $paramName | $SAWK '{print $3}'`

ret=$?

if [ $ret -eq 0 ]
then
  if [ $paramValue -ge $expected ]
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


_HOST=`/usr/bin/hostname`

SAWK="/bin/awk"
SGREP="/bin/grep"
SSED="/bin/sed"
NO="/usr/sbin/no"



# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while retrieving network parameter information on the system</EXEC_ERROR><TRACE>Unable to get the network parameter information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0274</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
exitstatus=3
expected=$3
paramName=$2
stage=$1

listOfInterfaces


if [ $stage = "-pre" ]
then 
  # the interface list is passed in the form "eth0:130.35.64.0:PUB,eth1:139.185.44.0:PVT", parse the first private interconnect
  interfaceTuple=$4
  interfaceNames=`echo $interfaceTuple |  $SAWK '{gsub(",","\n", $0); print}' | $SAWK -F: '{$3=tolower($3); print $1 ":" $2 ":" $3}' | $SSED -n -e '/:\([^:,]*\)pvt/p' -e '/:\([^:,]*\)cluster_interconnect/p' |  $SSED -e 's/\([^:,]*\):\([^:,]*\):\([^:,]*\)pvt/\1/' -e 's/\([^:]*\):\([^:]*\):\([^:,]*\)cluster_interconnect/\1/' | $SSED 's/"//g'`
else
  #in case of -post, the fourth paramter is the crs home
  CRS_HOME=$4
  interfaceNames=`$CRS_HOME/bin/oifcfg getif| $SGREP cluster_interconnect | $SAWK '{print \$1}'`
fi

if [ -z "$interfaceNames" ]
then
    result="<RESULT>VFAIL</RESULT><TRACE>The command line network parameter $paramName did not specify a cluster interconnect</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0275</ID><MSG_DATA><DATA>$paramName</DATA></MSG_DATA></NLS_MSG>"
    echo $result
    exit $exitstatus
fi

#strip off any new line characters
interfaceNames=`echo $interfaceNames`

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
 if [ ret -ne 0 ]
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

if [ "X$FAILED_INTERFACES" = "X" ]
then
    result="<RESULT>SUCC</RESULT><COLLECTED>$COLLECTED</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>The value of network parameter $paramName is set to the expected value $expected on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0272</ID><MSG_DATA><DATA>$paramName</DATA><DATA>$expected</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$FAILED_COLLECTED</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>The value of network parameter $paramName, for interfaces \"$FAILED_INTERFACES\", is not configured to the expected value on node $_HOST.[Expected=$expected; Found=$FAILED_COLLECTED]</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0273</ID><MSG_DATA><DATA>$paramName</DATA><DATA>$_HOST</DATA><DATA>$expected</DATA><DATA>$FAILED_COLLECTED</DATA><DATA>$FAILED_INTERFACES</DATA></MSG_DATA></NLS_MSG>"
fi

echo $result
exit $exitstatus

