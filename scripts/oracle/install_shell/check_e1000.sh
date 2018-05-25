#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_e1000.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_e1000.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_e1000.sh - script to check E1000 flow control
#
#    DESCRIPTION
#      script to check E1000 flow control
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       08/31/10 - shell script to check e1000 flow control
#    nvira       08/31/10 - Creation
#

SGREP="/bin/grep"
SAWK="/bin/awk"

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
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking flow control settings in the E1000</EXEC_ERROR><TRACE>Error while checking flow control settings in the E1000</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0304</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3
expected=false

case $PLATFORM in
  Linux)
      command="$SGREP e1000 /proc/modules |$SAWK '{print $1}'"
      enabled=`command`
      ret=$?
  ;;
esac

if [ $ret -eq 0 ]
then
  if [ "X$enabled " = "Xe1000" ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>false</COLLECTED><EXPECTED>false</EXPECTED><TRACE>E1000 flow control settings configured correctly on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0302</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>true</COLLECTED><EXPECTED>false</EXPECTED><TRACE>Potential problem with E1000 NIC exists on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0303</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking flow control settings in the E1000</EXEC_ERROR><TRACE>Error while checking flow control settings in the E1000</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0304</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   


echo $result
exit $existstatus
