#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_disk_asynch_io_linking.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_disk_asynch_io_linking.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_disk_asynch_io_linking.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       10/20/10 - script to check if the oracle binary is linked with
#                           async IO libraries
#    nvira       10/20/10 - Creation
#

SCAT="/bin/cat"
SGREP="/bin/grep"
NM="/usr/bin/nm"
WC="/usr/bin/wc"

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
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking async IO linking</EXEC_ERROR><TRACE>Error while checking async IO linking<TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0364</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3

ORACLE_HOME=$1

command="$NM $ORACLE_HOME/bin/oracle | $SGREP  -i 'getevents@@LIBAIO'| $WC -l"

libaioRefernceCount=$(/bin/sh -c "$command")


if [ $ret -eq 0 ]
then
  if [ $libaioRefernceCount -ge 1 ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>disk_asynch_io = enabled</COLLECTED><EXPECTED>disk_asynch_io = enabled</EXPECTED><TRACE>Oracle is linked with async IO libraries on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0362</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>disk_asynch_io = disabled</COLLECTED><EXPECTED>disk_asynch_io = enabled</EXPECTED><TRACE>Oracle is not linked with async IO libraries on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0363</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking async IO linking</EXEC_ERROR><TRACE>Error while checking async IO linking<TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0364</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   

echo $result
exit $existstatus
