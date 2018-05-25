#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_default_gateway.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_default_gateway.sh
#
# Copyright (c) 2010, 2011, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_default_gateway.sh - script to check if the default gateway is on same subnet as VIP 
#
#    DESCRIPTION
#      script to check if the default gateway is on same subnet as VIP 
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       09/02/10 - pluggable script to check subnet of default gateway
#    nvira       09/02/10 - Creation
#

SGREP="/bin/grep"
SAWK="/bin/awk"
SNETSTAT="/bin/netstat"
SHEAD="/usr/bin/head"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
esac

CRS_HOME=$1
exitstatus=0

vipsubnet=`$CRS_HOME/bin/oifcfg getif | $SGREP public | $SHEAD -1 | $SAWK '{print \$2}'`

ret=$?

if [ $ret -eq 0 ]
then

  dgsubnet=`$SNETSTAT -r | $SGREP $vipsubnet | $SAWK '{print \$1}'`
  ret=$?

  if [ $ret -eq 0 ]
  then
    if [ "$vipsubnet" = "$dgsubnet" ]
    then
      result="<RESULT>SUCC</RESULT><COLLECTED>VIP_SUBNET=$vipsubnet; GATEWAY_SUBNET=$dgsubnet</COLLECTED><EXPECTED>VIP_SUBNET = GATEWAY_SUBNET</EXPECTED><TRACE>VIP[$vipsubnet] and Default gateway[$dgsubnet] are on the same subnet on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0312</ID><MSG_DATA><DATA>$vipsubnet</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    else
      result="<RESULT>VFAIL</RESULT><COLLECTED>VIP_SUBNET=$vipsubnet; GATEWAY_SUBNET=$dgsubnet</COLLECTED><EXPECTED>VIP_SUBNET = GATEWAY_SUBNET</EXPECTED><TRACE>VIP[$vipsubnet] and Default gateway[$dgsubnet] are NOT on the same subnet on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0313</ID><MSG_DATA><DATA>$vipsubnet</DATA><DATA>$dgsubnet</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    fi
  else
    result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking subnet of default gateway on node $_HOST</EXEC_ERROR><TRACE>Error while checking subnet of default gateway on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0314</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking subnet of default VIP on node $_HOST</EXEC_ERROR><TRACE>Error while checking subnet of VIP on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0315</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
fi


echo $result
exit $exitstatus
