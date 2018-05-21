#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/bdump_dest_trace_analyzer.sh /st_has_12.1/1 2014/04/24 22:55:53 nvira Exp $
#
# bdump_dest_trace_analyzer.sh
#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      bdump_dest_trace_analyzer.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      Analyzer script to check whether background_dump_dest has too many old background dump files
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       04/10/14 - Backport nvira_bug-17315187 from main
#    nvira       01/29/14 - bug fix 17315187, use Java to execute analyzer
#                           script on remote nodes
#    nvira       10/06/10 - external analyzer to verify old trace files in
#                           bdump_dest
#    nvira       10/06/10 - Creation
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
bdump_dest=$4
ageInDays=$5
expectedCount=$6


instance_id=${dbName}"("${instance_id}")"

ret=0
count=0

resultSet="<RESULTSET>"
exitStatus=0

count=`find $bdump_dest -name '*.trc' -mtime +$ageInDays 2>/dev/null |wc -l`
ret=$?

if [ $ret -eq 0 ]
then
  if [ $count -le $expectedCount ]
    then
      resultSet=${resultSet}"<RESULT><STATUS>SUCC</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>background_dump_dest does not have too many old background dump files</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2912</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  else
      resultSet=${resultSet}"<RESULT><STATUS>VFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>background_dump_dest has too many old background dump files</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2913</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  fi   
else
  resultSet=${resultSet}"<RESULT><STATUS>EFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><EXEC_ERROR>Error while checking background dump destination</EXEC_ERROR><TRACE>Error while checking background dump destination</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2914</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
fi   

resultSet=${resultSet}"</RESULTSET>"

echo $resultSet
exit $exitStatus

