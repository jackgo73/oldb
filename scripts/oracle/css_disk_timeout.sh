#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/css_disk_timeout.sh /main/3 2013/10/28 12:19:25 dsaggi Exp $
#
# css_disk_timeout.sh
#
# Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      css_disk_timeout.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    dsaggi      10/24/13 - XbranchMerge agorla_bug-13002015 from st_has_11.2.0
#    nvira       08/11/10 - script to check css disk timeout
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

existstatus=3
expected=200
CRS_HOME=$1

#determine presence of vendor clusterware on SunOS or HP-UX and set the
#reference value accordingly
vcluster=1 #holds zero if vendor cluster is present
if [ $PLATFORM = SunOS ]
then
  if  [ -f /opt/ORCLcluster/lib/libskgxn2.so ]
  then
    vcluster=0
  fi 
elif [ $PLATFORM = HP-UX ]
then
  if  [ -f /opt/nmapi/nmapi2/lib/hpux64/libnmapi2.so ]
  then
    vcluster=0
  fi 
fi

if [ $vcluster -eq 0 ]
then
  expected=597
fi

# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXPECTED>$expected</EXPECTED><EXEC_ERROR>Error while CSS disktimeout settings</EXEC_ERROR><TRACE>Unable to get the CSS disktimeout settings on the sytem</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0354</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"

command="$CRS_HOME/bin/crsctl get css disktimeout"
css_disktimeout=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
  command="echo "$css_disktimeout" | sed 's/CRS-4678:\([^0-9]*\)\([0-9]*\)\(.*\)/\2/'"
  css_disktimeout=$(/bin/sh -c "$command")

  if [ $css_disktimeout -eq $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$css_disktimeout</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS disktimeout is set to recommended value of $expected on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0352</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$css_disktimeout</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS disktimeout is not set to recommended value of $expected on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0353</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
fi   

echo $result
exit $existstatus
