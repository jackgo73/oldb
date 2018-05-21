#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/css_reboot_time.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# css_reboot_time.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      css_reboot_time.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       08/11/10 - script to check css reboot time
#    nvira       08/11/10 - Creation
#

SCAT="/bin/cat"
SGREP="/bin/grep"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

expected=3
CRS_HOME=$1

# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXPECTED>$expected</EXPECTED><EXEC_ERROR>Error while CSS reboottime settings</EXEC_ERROR><TRACE>Unable to get the CSS reboottime settings on the sytem</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0264</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3


command="$CRS_HOME/bin/crsctl get css reboottime"
css_reboot_time=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
  command="echo "$css_reboot_time" | sed 's/CRS-4678:\([^0-9]*\)\([0-9]*\)\(.*\)/\2/'"
  css_reboot_time=$(/bin/sh -c "$command")
  if [ $css_reboot_time -eq $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$css_reboot_time</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS reboottime is not set to recommended value of $expected on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0262</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$css_reboot_time</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS reboottime is set to recommended value of $expected on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0263</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>VFAIL</RESULT><COLLECTED>NOT SET</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS reboottime is set to recommended value of $expected on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0263</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=2
fi   



echo $result
exit $existstatus
