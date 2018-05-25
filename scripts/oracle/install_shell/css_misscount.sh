#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/css_misscount.sh /main/5 2013/10/28 12:19:25 dsaggi Exp $
#
# css_misscount.sh
#
# Copyright (c) 2010, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      css_misscount.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    dsaggi      10/24/13 - XbranchMerge agorla_bug-13002015 from st_has_11.2.0
#    nvira       09/04/13 - bug fix 17386099, change the check for major number
#                           10 to work on HPI
#    ptare       03/22/12 - Bug#13839554 Change the default expected value of CSS misscount
#                           from 60 to 30 based on current version of crs
#    nvira       08/11/10 - pluggable script to check css misscount settings
#    nvira       08/09/10 - pluggable script for css misscount
#    nvira       08/09/10 - Creation
#

SCAT="/bin/cat"
SGREP="/bin/grep"

CRS_HOME=$1
CRS_ACTIVE_VERSION=$2
CRS_MAJOR_NUMBER=`echo $CRS_ACTIVE_VERSION | sed 's/\(..\)\..*/\1/'`

PLATFORM=`/bin/uname`

#Set the default reference value for css misscount
case $PLATFORM in
  Linux)
      #the expected css misscount varies by current version of crs, mainly between release 10 and 11 or further, hence set it accordingly
      if [[ "$CRS_MAJOR_NUMBER" -eq "10" ]]
      then 
       expected=60
      else
       expected=30
      fi
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      expected=30
      _HOST=`/usr/bin/hostname`
  ;;
esac

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
  expected=600
fi

# Set default exit message to indicate failure.
result="<RESULT>EFAIL</RESULT><EXPECTED>$expected</EXPECTED><EXEC_ERROR>Error while CSS misscount settings</EXEC_ERROR><TRACE>Unable to get the CSS misscount settings on the sytem</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0254</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
existstatus=3

command="$CRS_HOME/bin/crsctl get css misscount"
css_misscount=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
  command="echo "$css_misscount" | sed 's/CRS-4678:\([^0-9]*\)\([0-9]*\)\(.*\)/\2/'"
  css_misscount=$(/bin/sh -c "$command")

  if [ $css_misscount -ge $expected ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$css_misscount</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS misscount is set to recommended value of $expected or more on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0252</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=0
  else
    result="<RESULT>VFAIL</RESULT><COLLECTED>$css_misscount</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>CSS misscount is not set to recommended value of $expected or more on $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0253</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    existstatus=2
  fi   
fi   

echo $result
exit $existstatus
