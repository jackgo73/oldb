#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_vmm.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# check_vmm.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_vmm.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       08/23/10 - script to check virtual memory management
#                           parameters
#    nvira       08/23/10 - Creation
#

AWK="/usr/bin/awk"
VMO="/usr/sbin/vmo"

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while virtual memory parameter information on the system</EXEC_ERROR><TRACE>Unable to get the hang check timer setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0284</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
existstatus=3
expected=$2

command="$VMO -o $1 | awk '{print $3}'"
vmm_param=`command`
ret=$?

if [ $ret -eq 0 ]
then
  if [ $vmm_param -eq $expected ]
  then 
    result="<RESULT>SUCC</RESULT><COLLECTED>$vmm_param</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>The value of virtual memory parameter $1 is set to the expected value $2 on node $_HOST.</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0282</ID><MSG_DATA><DATA>$1</DATA><DATA>$2</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>WARN</RESULT><COLLECTED>$vmm_param</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>The value of virtual memory parameter $1 is not set to the expected value on node $_HOST.[Expected=$2; Found=$vmm_param]</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0283</ID><MSG_DATA><DATA>$1</DATA><DATA>$_HOST</DATA><DATA>$2</DATA><DATA>$vmm_param</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while virtual memory parameter information on the system</EXEC_ERROR><TRACE>Unable to get the hang check timer setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0284</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   



echo $result
exit $existstatus

