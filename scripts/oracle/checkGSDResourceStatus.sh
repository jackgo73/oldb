#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checkGSDResourceStatus.sh /main/1 2013/11/03 21:38:17 maboddu Exp $
#
# checkGSDResourceStatus.sh
#
# Copyright (c) 2013, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checkGSDResourceStatus.sh - check the status of ora.gsd resource 
#
#    DESCRIPTION
#      Check the status of ora.gsd resource and warn the user to stop the resource if 
#      it is running during upgrade to 121 or later
#
#    NOTES
#
#    MODIFIED   (MM/DD/YY)
#    maboddu     09/30/13 - Fix bug#17494773 - Check ora.gsd resource status
#    maboddu     09/30/13 - Creation
#

SGREP="/bin/grep"
SAWK="/bin/awk"
CRS_HOME=$1

#check the status of ora.gsd resource with crsctl command
status=`$CRS_HOME/bin/crsctl stat res ora.gsd | $SGREP STATE | $SAWK '{split($0,a,"="); print a[2]}'`
isEnable=`$CRS_HOME/bin/crsctl stat res ora.gsd -p | $SGREP ENABLED | $SAWK '{split($0,a,"="); print a[2]}'`

if [ "$status" = "ONLINE" ] &&  [ "$isEnable" = "1" ] 
then
  RESULT="<RESULT>WARN</RESULT><EXPECTED>OFFLINE</EXPECTED><TRACE>ora.gsd resource is running and enabled on node $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10155</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
elif [ "$isEnable" = "1" ]
  RESULT="<RESULT>WARN</RESULT><EXPECTED>OFFLINE</EXPECTED><TRACE>ora.gsd resource is enabled on node $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10156</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
else
  RESULT="<RESULT>SUCC</RESULT><TRACE>ora.gsd resource is offline on node $HOST</TRACE>"
fi;

echo $RESULT


