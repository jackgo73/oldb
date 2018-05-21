#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/hangchecktimer.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# hangchecktimer.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      hangchecktimer.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       10/21/10 - script to check hangchecktimer
#    nvira       07/21/10 - pluggable script for checking hang timer setting
#    nvira       07/21/10 - Creation
#

SCAT="/bin/cat"
SGREP="/bin/grep"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac


# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while hang check timer setting information on the system</EXEC_ERROR><TRACE>Unable to get the hang check timer setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0234</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3

case $PLATFORM in
  Linux)
      command="/sbin/lsmod |grep hangcheck_timer |awk '{print $1}'"
      hangchecktimer=$(/bin/sh -c "$command")
      ret=$?
  ;;
esac


if [ $ret -eq 0 ]
then
  if [ "X$hangchecktimer" = "X" ]
  then
    result="<RESULT>VFAIL</RESULT><COLLECTED>not loaded</COLLECTED><EXPECTED>loaded</EXPECTED><TRACE>Hangcheck timer is NOT set on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0233</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  else
    result="<RESULT>SUCC</RESULT><COLLECTED>loaded</COLLECTED><EXPECTED>loaded</EXPECTED><TRACE>Hangcheck timer is set on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0232</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while hang check timer setting information on the system</EXEC_ERROR><TRACE>Unable to get the hang check timer setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0234</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   

echo $result
exit $existstatus
