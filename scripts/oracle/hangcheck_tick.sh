#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/hangcheck_tick.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# hangcheck_tick.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      hangcheck_tick.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       10/21/10 - script to check hangcheck_tick
#    nvira       10/21/10 - Creation
#

SCAT="/bin/cat"
SGREP="/bin/grep"
SAWK="/bin/awk"
SED="/bin/sed"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

case $PLATFORM in
  Linux)
      command="$SCAT /etc/modprobe.conf | $SED '/^[ \t]*#/d'  | $SED -e :a -e '/\\\[ \t]*$/N; s/\\\\\n//; ta' |$SGREP hangcheck-timer|$SED -n 's/.*hangcheck_tick=//p'|$SAWK '{print \$1}'"
      hangcheck_tick=$(/bin/sh -c "$command")
      ret=$?
  ;;
esac

expected=1

if [ "X$hangcheck_tick" == "X" ]
then
  result="<RESULT>VFAIL</RESULT><COLLECTED>hangcheck_tick = NOT SET</COLLECTED><EXPECTED>hangcheck_tick = $expected</EXPECTED><TRACE>hangcheck_tick is NOT configured properly on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0393</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=2
  echo $result
  exit $existstatus
fi   

if [ $ret -eq 0 ]
then
  if [ $hangcheck_tick -ne $expected ]
  then
    result="<RESULT>VFAIL</RESULT><COLLECTED>hangcheck_tick = $hangcheck_tick</COLLECTED><EXPECTED>hangcheck_tick = $expected</EXPECTED><TRACE>hangcheck_tick is NOT configured properly on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0393</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  else
    result="<RESULT>SUCC</RESULT><COLLECTED>hangcheck_tick = $hangcheck_tick</COLLECTED><EXPECTED>hangcheck_tick = $expected</EXPECTED><TRACE>hangcheck_tick is configured properly on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0392</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  fi   
else
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking hangcheck_tick setting information on the system</EXEC_ERROR><TRACE>Unable to get the hangcheck_tick setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0394</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=3
fi   

echo $result
exit $existstatus
