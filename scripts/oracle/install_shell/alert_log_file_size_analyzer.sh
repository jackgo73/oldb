#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/alert_log_file_size_analyzer.sh /st_has_12.1/1 2014/04/24 22:55:53 nvira Exp $
#
# alert_log_file_size_analyzer.sh
#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      alert_log_file_size_analyzer.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      Analyzer script to analyze size of the alert log files
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       04/10/14 - Backport nvira_bug-17315187 from main
#    nvira       01/29/14 - bug fix 17315187, use Java to execute analyzer
#                           script on remote nodes
#    nvira       10/05/10 - Creation
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

dbName=$1
nodeName=$2
instance_id=$3
alert_dest=$4
expectedSize=$5
expectedCount=0

instance_id=${dbName}"("${instance_id}")"

# Set default exit message to indicate failure.
 result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking the size of alert log file</EXEC_ERROR><TRACE>Error while checking the size of alert log file</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2894</ID><MSG_DATA><DATA>$dbName</DATA></MSG_DATA></NLS_MSG>"
exitStatus=0

resultSet="<RESULTSET>"
exitStatus=0

count=`find $alert_dest -name 'alert*.log' -size +$expectedSize 2>/dev/null|wc -l`
ret=$?

if [ $ret -eq 0 ]
then
  if [ $count -le $expectedCount ]
    then
      resultSet=${resultSet}"<RESULT><STATUS>SUCC</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>Alert log is not too big</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2892</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  else
      resultSet=${resultSet}"<RESULT><STATUS>VFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>$count</COLLECTED><EXPECTED>$expectedCount</EXPECTED><TRACE>Alert log file is too big and should be rolled over periodically</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2893</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  fi   
else
  resultSet=${resultSet}"<RESULT><STATUS>EFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><EXEC_ERROR>Error while checking for ORA-00600 errors in alert log</EXEC_ERROR><TRACE>Error while checking the size of alert log file</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2894</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
fi   

resultSet=${resultSet}"</RESULTSET>"

echo $resultSet
exit $exitStatus
