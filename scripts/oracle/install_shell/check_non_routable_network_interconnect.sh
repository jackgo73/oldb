#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_non_routable_network_interconnect.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_non_routable_network_interconnect.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_non_routable_network_interconnect.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       10/20/10 - script to check Non-routable network for
#                           interconnect
#    nvira       10/20/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SGREP="grep"
SAWK="awk"
SNETSTAT="netstat"
SHEAD="head"

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

command="$CRS_HOME/bin/oifcfg getif|grep cluster_interconnect|awk '{print $2}'|cut -d . -f1|grep -c -E '10|172|192'"

nonRoutableNetworkCheck=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
	if [ $nonRoutableNetworkCheck -eq 1 ]
	then
	  result="<RESULT>SUCC</RESULT><COLLECTED>non_routable_network = true</COLLECTED><EXPECTED>non_routable_network = true</EXPECTED><TRACE>Interconnect is configured on non-routable network addresses on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0372</ID><MSG_DATA><DATA>$vipsubnet</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
	  existstatus=0
	else
	  result="<RESULT>VFAIL</RESULT><COLLECTED>non_routable_network = false</COLLECTED><EXPECTED>non_routable_network = true</EXPECTED><TRACE>Interconnect should not be configured on routable network addresses on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0373</ID><MSG_DATA><DATA>$vipsubnet</DATA><DATA>$dgsubnet</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
	  existstatus=2
	fi
else
	result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking network for interconnect on node $_HOST</EXEC_ERROR><TRACE>Error while checking network for interconnect on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0374</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
	existstatus=3
fi   


echo $result
exit $existstatus
