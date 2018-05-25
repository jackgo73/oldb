#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/css_diagwait.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# css_diagwait.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      css_diagwait.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       08/09/10 - pluggable script for css diagwait check
#    nvira       08/09/10 - Creation
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

existstatus=3
CRS_HOME=$1
expected=13


# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXPECTED>$expected</EXPECTED><EXEC_ERROR>Error while CSS Diagwait settings</EXEC_ERROR><TRACE>Unable to get the CSS Diagwait settings on the sytem</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0244</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"

command="$CRS_HOME/bin/crsctl get css diagwait"
css_diagwait=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
  command="echo $css_diagwait | sed 's/CRS-4678:\([^0-9]*\)\([0-9]*\)\(.*\)/\2/'"
  css_diagwait=$(/bin/sh -c "$command")

  if [ $css_diagwait -eq $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$css_diagwait</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS Diagwait is set to recommended value of $expected on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0242</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$css_diagwait</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS Diagwait is not set to recommended value of $expected on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0243</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
else
  result="<RESULT>VFAIL</RESULT><COLLECTED>NOT SET</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS Diagwait is not set to recommended value of $expected on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0243</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=2
fi   



echo $result
exit $existstatus
