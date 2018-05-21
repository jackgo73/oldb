#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checkIOCPDeviceStatus.sh /main/1 2014/03/11 23:31:05 maboddu Exp $
#
# checkIOCPDeviceStatus.sh
#
# Copyright (c) 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      checkIOCPDeviceStatus.sh - check the status of IOCP device
#
#    DESCRIPTION
#      In AIX, the IOCP need to be available on the host for I/O operations.
#      Report error if IOCP status is not Available
#
#    NOTES
#
#    MODIFIED   (MM/DD/YY)
#    maboddu     02/20/14 - Fix bug#18029051 - Check the status of iocp device
#    maboddu     02/20/14 - Creation
#

LSDEV="/etc/lsdev"
SAWK="/bin/awk"

#Check the status of IOCP device
status=`$LSDEV -Cc iocp | $SAWK '{print $2}'`

ret=$?
if [ $ret -eq 0 ]
then
   if [ "$status" = "Available" ] 
   then
      RESULT="<RESULT>SUCC</RESULT><TRACE>IOCP device status is $status</TRACE>"
   else
      RESULT="<RESULT>VFAIL</RESULT><EXPECTED>Available</EXPECTED><TRACE>IOCP device status is $status on node $HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10167</ID><MSG_DATA><DATA>$HOST</DATA><DATA>$status</DATA></MSG_DATA></NLS_MSG>"
   fi;
else
   RESULT="<RESULT>WARN</RESULT><EXEC_ERROR>Error while getting the status of IOCP device</EXEC_ERROR><TRACE>Failed to get the IOCP device status</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10168</ID><MSG_DATA><DATA>$LSDEV</DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
fi;


echo $RESULT


