#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/checkportavail.sh /main/4 2011/05/09 01:25:53 narbalas Exp $
#
# checkportavail.sh
#
# Copyright (c) 2010, 2011, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checkportavail.sh - Check whether ports are available
#
#    DESCRIPTION
#      
#
#    NOTES
#      Given parameter as port number checks whether the port is
#      available using netstat command
#
#    MODIFIED   (MM/DD/YY)
#    narbalas    04/20/11 - Fix 12371684
#    nvira       09/29/10 - set expected value
#    narbalas    09/09/10 - Initial Version
#    narbalas    09/09/10 - Creation
#
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/etc
PORT=$1
PROTOCOL=$2
PROTOCOL="^PROTOCOL"
SGREP="grep"
EGREP="grep -E"
SNETSTAT="netstat -an"
INETSTAT="netstat -in"
SIFCONFIG="ifconfig"
AIFCONFIG="ifconfig -a"
SECHO="echo"
SAWK="awk"
adieu()
{
  echo $RESULT
  exit
}

case $PORT in
    "") RESULT="<RESULT>EFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Check for port availability encountered a command failure </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0047</ID></NLS_MSG>"
       adieu;;
    *)
esac
case $PROTOCOL in
    "") RESULT="<RESULT>EFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Check for port availability encountered a command failure </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0047</ID></NLS_MSG>"
       adieu;;
    *)
esac
PLATFORM=`/bin/uname`
case $PLATFORM in
  Linux)
      IFLIST=`$SIFCONFIG | $SGREP 'inet addr' | $SAWK -F: '{ print $2 }' | $SAWK '{ print $1 }'`
      IPLIST=`echo $IFLIST | sed 's/ /|/g'`
      PORTLIST=`$SNETSTAT | $SGREP $PROTOCOL | $SAWK '{ printf "%s\n%s\n",$4,$5 }' | $EGREP "$IPLIST" | $SAWK -F: '{ print $2 }'`
  ;;
  HP-UX)
      IFLIST=`$INETSTAT  | $SAWK -F" " '{ print $3 }'`
      IPLIST=`echo $IFLIST | sed 's/ /|/g'`
      PORTLIST=`$SNETSTAT | $SGREP $PROTOCOL | $SAWK '{ printf "%s\n%s\n",$4,$5 }' | $EGREP "$IPLIST" | $SAWK -F: '{ print $2 }'`
  ;;
  AIX)
      IFLIST=`$AIFCONFIG  | $SGREP 'inet ' | $SAWK '{ print $2 }'`
      IPLIST=`echo $IFLIST | sed 's/ /|/g'`
      PORTLIST=`$SNETSTAT | $SGREP $PROTOCOL | $SAWK '{ printf "%s\n%s\n",$4,$5 }' | $EGREP "$IPLIST" | $SAWK -F. '{ print $5 }'`
  ;;
esac
echo $PORTLIST | $SGREP $PORT >/dev/null 2>&1
if [ $? -eq 0 ]
then
    RESULT="<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Check for port $PORT availability failed on node $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0048</ID><MSG_DATA><DATA>$PORT</DATA></MSG_DATA></NLS_MSG>"
else
    RESULT="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Check for port $PORT availability passed on node $HOST</TRACE>"
fi
adieu

