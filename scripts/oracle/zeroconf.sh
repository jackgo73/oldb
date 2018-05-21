#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/zeroconf.sh /st_has_12.1/1 2014/06/10 21:37:00 ptare Exp $
#
# zeroconf.sh
#
# Copyright (c) 2011, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      zeroconf.sh - checks the presence of NOZEROCONF in /etc/sysconfig/network
#
#    DESCRIPTION
#      On SLES/SUSE:
#        Check that LINKLOCAL_INTERFACES entry does not exists inside /etc/sysconfig/network/config
#      On RHEL/OEL:
#        Checks the presence of NOZEROCONF in /etc/sysconfig/network. if NOZEROCONF does not present or
#      it is not set to yes, route for 169.254/16 is generated. this may cause some problems.
#
#    NOTES
#      
#
#    MODIFIED   (MM/DD/YY)
#    ptare       06/10/14 - XbranchMerge ptare_bug-18912532 from main
#    ptare       06/06/14 - Fix Bug#18912532 handle separately on SLES
#    agorla      05/06/11 - bug#9968337 - check for zeroconf
#    agorla      05/06/11 - Creation
#

GREP="/bin/grep"
LS="ls"
HOSTNAME="/bin/hostname"
host=`${HOSTNAME}`

#SUSE platform needs a separate handling, check if we are on SUSE
SUSERELEASE=`${LS} /etc | ${GREP} -i suse | ${GREP} -i release`
SUSERELEASE_FILE="/etc/$SUSERELEASE"
SLESRELEASE=`${LS} /etc | ${GREP} -i sles | ${GREP} -i release`
SLESRELEASE_FILE="/etc/$SLESRELEASE"

if [ -f $SUSERELEASE_FILE ] || [ -f $SLESRELEASE_FILE ]
then
  # We are on SUSE linux platform 
  netfile="/etc/sysconfig/network/config"
  paramName="LINKLOCAL_INTERFACES"

  if [ "X$1" = "X-getfixupdata" ]; then
    echo "$paramName,$netfile"
  else
    $GREP "^[[:space:]]*LINKLOCAL_INTERFACES[[:space:]]*=" $netfile >/dev/null
    if [ $? -eq 0 ]
    then
      echo "<RESULT>VFAIL</RESULT><COLLECTED><NLS_MSG><FACILITY>Prve</FACILITY><ID>0056</ID><MSG_DATA><DATA>${paramName}</DATA></MSG_DATA></NLS_MSG></COLLECTED><EXPECTED><NLS_MSG><FACILITY>Prve</FACILITY><ID>0057</ID><MSG_DATA><DATA>${paramName}</DATA></MSG_DATA></NLS_MSG></EXPECTED><NLS_MSG><FACILITY>Prve</FACILITY><ID>10078</ID><MSG_DATA><DATA>${host}</DATA></MSG_DATA></NLS_MSG>"
    else
      echo "<RESULT>SUCC</RESULT><COLLECTED><NLS_MSG><FACILITY>Prve</FACILITY><ID>0057</ID><MSG_DATA><DATA>${paramName}</DATA></MSG_DATA></NLS_MSG></COLLECTED><EXPECTED><NLS_MSG><FACILITY>Prve</FACILITY><ID>0057</ID><MSG_DATA><DATA>${paramName}</DATA></MSG_DATA></NLS_MSG></EXPECTED><TRACE>LINKLOCAL_INTERFACES is not set inside ${netfile} on node ${host}</TRACE>"  
    fi
  fi
else
  #We are on OL/OEL or RHEL platforms
  netfile="/etc/sysconfig/network"
  paramName="NOZEROCONF"
  catfile=`cat /etc/sysconfig/network`
  catorigfile=`cat /etc/sysconfig/network-orig`
  if [ "X$1" = "X-getfixupdata" ]; then
    echo "$paramName,$netfile"
  else
    $GREP -i "^[[:space:]]*NOZEROCONF[ \t]*=[ \t]*yes" $netfile >/dev/null

    if [ $? -eq 0 ]
    then
      echo "<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>NOZEROCONF is set to yes in ${netfile} on node ${host}</TRACE>" 
    else
      echo "<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>NOZEROCONF was not set to yes in ${netfile} on node ${host}. Cat output = $catfile. Cat orig output = $catorigfile</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10077</ID><MSG_DATA><DATA>${host}</DATA></MSG_DATA></NLS_MSG>"
    fi
  fi
fi

exit 0
