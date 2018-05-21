#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_vip_restart_attempt.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_vip_restart_attempt.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_vip_restart_attempt.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       09/03/10 - script to check vip restart attempt
#    nvira       09/03/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SCAT="cat"
SGREP="grep"

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
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking VIP restart_attempt</EXEC_ERROR><TRACE>Error while checking VIP restart_attempt</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0324</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3
CRS_HOME=$1

case $PLATFORM in
  Linux)
      command="$CRS_HOME/bin/crs_stat -p ora.`hostname|cut -d. -f1`.vip|grep -i restart|cut -d= -f2"
      attempt=$(/bin/sh -c "$command")
      ret=$?
  ;;
esac


if [ $ret -eq 0 ]
then
  if [ $attempt -eq 0 ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$attempt</COLLECTED><EXPECTED>0</EXPECTED><TRACE>VIP restart_attempt=0 on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0322</ID><MSG_DATA><DATA>$attempt</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>WARN</RESULT><COLLECTED>$attempt</COLLECTED><EXPECTED>0</EXPECTED><TRACE>VIP restart_attempt[$attempt] > 0 on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0323</ID><MSG_DATA><DATA>$attempt</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking VIP restart_attempt</EXEC_ERROR><TRACE>Error while checking VIP restart_attempt</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0324</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   

echo $result
exit $existstatus
