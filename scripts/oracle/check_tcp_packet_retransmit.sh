#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_tcp_packet_retransmit.sh /main/3 2012/05/15 18:58:50 nvira Exp $
#
# check_tcp_packet_retransmit.sh
#
# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_tcp_packet_retransmit.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       09/02/10 - script to check tcp packet retransmissions
#    nvira       09/02/10 - Creation
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
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking TCP retransmissions</EXEC_ERROR><TRACE>Error while checking TCP retransmissions</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0334</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3
expected=$1

case $PLATFORM in
  SunOS)
    tcpOutDataBytes=`netstat -sP tcp|grep tcpOutDataBytes| cut -d= -f3`;tcpRetransBytes=`netstat -sP tcp|grep tcpRetransBytes| cut -d= -f3`;echo "scale =10;$tcpRetransBytes / $tcpOutDataBytes*100"|bc|awk '{print int($1+0.5)}'
    ret=$?
  ;;
esac


if [ $ret -eq 0 ]
then
  if [ $tcpOutDataBytes -le $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$tcpOutDataBytes</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>TCP retransmissions [$tcpOutDataBytes] is not too high on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0332</ID><MSG_DATA><DATA>$tcpOutDataBytes</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>WARN</RESULT><COLLECTED>$tcpOutDataBytes</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>TCP retransmissions [$tcpOutDataBytes] is too high on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0333</ID><MSG_DATA><DATA>$tcpOutDataBytes</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking TCP retransmissions</EXEC_ERROR><TRACE>Error while checking TCP retransmissions</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0334</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   



echo $result
exit $existstatus
