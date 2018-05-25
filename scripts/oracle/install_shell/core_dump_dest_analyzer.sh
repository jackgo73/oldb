#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/core_dump_dest_analyzer.sh /st_has_12.1/1 2014/04/24 22:55:53 nvira Exp $
#
# core_dump_dest_analyzer.sh
#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      core_dump_dest_analyzer.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      Analyzer to script to check whether core_dump_dest has too many old core dump files
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       04/10/14 - Backport nvira_bug-17315187 from main
#    nvira       01/29/14 - bug fix 17315187, use Java to execute analyzer
#                           script on remote nodes
#    nvira       10/04/10 - shell script to analyze results of core dump dest
#                           sql query
#    nvira       10/04/10 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SGREP="grep"
SAWK="awk"
SCUT="cut"
SCAT="cat"

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

exitStatus=3
dbName=$1
nodeName=$2
instance_id=$3
cdump_dest=$4
ageInDays=$5
expectedCount=$6

instance_id=${dbName}"("${instance_id}")"

resultSet="<RESULTSET>"
exitStatus=0

tempCount=0
count=0

command="find $cdump_dest -name '*.trc' -mtime +$ageInDays 2>/dev/null |wc -l"
count=$(/bin/sh -c "$command")
ret=$?

if [ $ret -eq 0 ]
then
  if [ $count -le $expectedCount ]
    then
      resultSet=${resultSet}"<RESULT><STATUS>SUCC</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>core_dump_dest not have too many old core dump files</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2872</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  else
      resultSet=${resultSet}"<RESULT><STATUS>VFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>core_dump_dest has too many old core dump files</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2873</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  fi   
else
  resultSet=${resultSet}"<RESULT><STATUS>EFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><EXEC_ERROR>Error while checking core dump destination</EXEC_ERROR><TRACE>Error while checking background dump destination</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2874</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
fi   

resultSet=${resultSet}"</RESULTSET>"

echo $resultSet
exit $exitStatus

