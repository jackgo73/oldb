#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checkIPHostModel.sh /main/1 2013/08/11 22:36:57 maboddu Exp $
#
# checkIPHostModel.sh
#
# Copyright (c) 2013, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checkIPHostModel.sh - checks the hostmodel of IP protocol 
#
#    DESCRIPTION
#      Checks the IP hostmodel of IP protocols(both ipv4 and ipv6)
#      and gives the error message if the hostmodel is strong.
#
#    NOTES
#
#
#    MODIFIED   (MM/DD/YY)
#    maboddu     07/22/13 - Check for strong IP hostmodel 
#    maboddu     07/22/13 - Creation
#

IPADM="/usr/sbin/ipadm"
IFCONFIG="/sbin/ifconfig"
SGREP="/bin/grep"
SAWK="/bin/awk"
SED="/bin/sed"

# the interface list is passed in the form "eth0:130.35.64.0:PUB,eth1:139.185.44.0:PVT"
interfaceTuple=$1
nicArray=`echo $interfaceTuple | $SAWK '{gsub(",","\n", $0); print}' |  $SED 's/\([^:]*\):\([^:]*\):\([^:]*\)/\1/' | $SED 's/"//g'`

for nicname in $nicArray
do
  paramValue=`$IFCONFIG $nicName | $SGREP -i "ipv4"`
  if [ "X$paramValue" != "X" ]
  then
     IPV4=true;
  fi;
  paramValue=`$IFCONFIG $nicName | $SGREP -i "ipv6"`
  if [ "X$paramValue" != "X" ]
  then
     IPV6=true;
  fi;
done

if [ "$IPV4" = "true" ]
then
   HOSTMODEL4 = `$IPADM show-prop -p hostmodel ip | $GREP "ipv4" | $SAWK '{print $4}'`
fi;
if [ "$IPV6" = "true" ]
then
   HOSTMODEL6 = `$IPADM show-prop -p hostmodel ip | $GREP "ipv6" | $SAWK '{print $4}'`
fi;

if [ "$HOSTMODEL4" = "strong" ] && [ "$HOSTMODEL6" = "strong" ]
then
   echo "<RESULT>VFAIL</RESULT><TRACE>The current IP hostmodel configuration for both IPV4 and IPV6 does not match the required configuration on node "$HOST" [Expected = "weak" ; Found = "strong"] </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10150</ID><MSG_DATA><DATA>$HOST</DATA><DATA>weak</DATA><DATA>strong</DATA></MSG_DATA></NLS_MSG>"

elif [ "$HOSTMODEL4" = "strong" ] 
then
   echo "<RESULT>VFAIL</RESULT><TRACE>The current IP hostmodel configuration for IPV4 does not match the required configuration on node "$HOST" [Expected = "weak" ; Found = "strong"] </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10151</ID><MSG_DATA><DATA>IPV4</DATA><DATA>$HOST</DATA><DATA>weak</DATA><DATA>strong</DATA></MSG_DATA></NLS_MSG>"

elif [ "$HOSTMODEL6" = "strong" ] 
then
   echo "<RESULT>VFAIL</RESULT><TRACE>The current IP hostmodel configuration for IPV6 does not match the required configuration on node "$HOST" [Expected = "weak" ; Found = "strong"] </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10151</ID><MSG_DATA><DATA>IPV6</DATA><DATA>$HOST</DATA><DATA>weak</DATA><DATA>strong</DATA></MSG_DATA></NLS_MSG>"

else
   echo "<RESULT>SUCC</RESULT><TRACE>The current IP hostmodel configuration for both IPV4 and IPV6 protocols match the required configuration on node $HOST</TRACE>"
fi;

