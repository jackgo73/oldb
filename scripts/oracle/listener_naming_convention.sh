#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/listener_naming_convention.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# listener_naming_convention.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      listener_naming_convention.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       10/22/10 - script to verify listener naming convention
#    nvira       10/22/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SCAT="cat"
SGREP="grep"
SAWK="awk"
SED="sed"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

command="$($CRS_HOME/bin/crs_stat|grep -i listener|grep `hostname|cut -d. -f1`|cut -d. -f3)"

lsnrname=$(/bin/sh -c "$command")

expected=1

if [ $ret -eq 0 ]
then
  command="echo $lsnrname|grep -ic `hostname|cut -d. -f1"
  available=$(/bin/sh -c "$command")

  if [ $available -ne $expected ]
  then
    result="<RESULT>VFAIL</RESULT><COLLECTED>lsnrname_endswith_hostname = false</COLLECTED><EXPECTED>lsnrname_endswith_hostname = true</EXPECTED><TRACE>Wrong naming convention followed for listener name on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0403</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  else
    result="<RESULT>SUCC</RESULT><COLLECTED>lsnrname_endswith_hostname = true</COLLECTED><EXPECTED>lsnrname_endswith_hostname = true</EXPECTED><TRACE>Correct naming convention followed for listener name on  on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0402</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error encountered while trying to obtain the listener name on node $_HOST</EXEC_ERROR><TRACE>Error encountered while trying to obtain the listener name on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0404</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   

echo $result
exit $existstatus
