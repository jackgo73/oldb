#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_network_packet_reassembly.sh /main/3 2012/05/15 18:58:50 nvira Exp $
#
# check_network_packet_reassembly.sh
#
# Copyright (c) 2010, 2012, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_network_packet_reassembly.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       09/02/10 - script to check network packet reassembly
#    nvira       09/02/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SCAT="cat"
SCUT="cut"
SGREP="grep"
SAWK="awk"
SNETSTAT="netstat"

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
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking TCP retransmissions</EXEC_ERROR><TRACE>Error while checking TCP retransmissions</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0344</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3
expected=$1

case $PLATFORM in
  SunOS)
    ipReasmOKs=` $SNETSTAT -sP ip | $SGREP ipReasmOKs| $SCUT -d= -f2| $SAWK '{print $1}'`;ipReasmReqds=`netstat -sP ip| $SGREP ipReasmReqds| $SCUT -d= -f3`;echo "scale =10;$ipReasmOKs - $ipReasmReqds"|bc
    ret=$?
  ;;
esac


if [ $ret -eq 0 ]
then
  if [ $ipReasmOKs -eq $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$ipReasmOKs</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Network packet reassembly not occuring on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0342</ID><MSG_DATA><DATA>$ipReasmOKs</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>WARN</RESULT><COLLECTED>$ipReasmOKs</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Network packet reassembly occuring on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0343</ID><MSG_DATA><DATA>$ipReasmOKs</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking TCP retransmissions</EXEC_ERROR><TRACE>Error while checking TCP retransmissions</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0344</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   


echo $result
exit $existstatus
