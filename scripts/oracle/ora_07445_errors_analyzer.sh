#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/ora_07445_errors_analyzer.sh /st_has_12.1/1 2014/04/24 22:55:53 nvira Exp $
#
# ora_07445_errors_analyzer.sh
#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      ora_07445_errors_analyzer.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      Analyzer script to check for ORA-07445 erorrs in the alert log
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       04/10/14 - Backport nvira_bug-17315187 from main
#    nvira       01/29/14 - bug fix 17315187, use Java to execute analyzer
#                           script on remote nodes
#    nvira       10/27/10 - script to check 07445 errors
#    nvira       10/27/10 - Creation
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
alert_dest=$4
expectedCount=$5

instance_id=${dbName}"("${instance_id}")"

# Set default exit message to indicate failure.
 result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while checking for ORA-07445 errors in alert log</EXEC_ERROR><TRACE>Error while checking for ORA-07445 errors in alert log</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2924</ID><MSG_DATA><DATA>$dbName</DATA></MSG_DATA></NLS_MSG>"

ret=0
count=0

resultSet="<RESULTSET>"

exitStatus=0

for alert_name in $(find "$alert_dest" -name 'alert_*.log' 2>/dev/null)
do
  command="grep -i 'ORA-07445' $alert_name|wc -l"
  tempCount=$(/bin/sh -c "$command")
  ret=$?
  count=$(($count+$tempCount))
done

if [ $ret -eq 0 ]
then
  if [ $count -le $expectedCount ]
    then
      resultSet=${resultSet}"<RESULT><STATUS>SUCC</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>ORA-07445_ERR_COUNT=$count</COLLECTED><EXPECTED>ORA-07445_ERR_COUNT=$expectedCount</EXPECTED><TRACE>No ORA-07445 errors found in alert log</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2922</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  else
      resultSet=${resultSet}"<RESULT><STATUS>VFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><COLLECTED>ORA-07445_ERR_COUNT=$count</COLLECTED><EXPECTED>ORA-07445_ERR_COUNT=$expectedCount</EXPECTED><TRACE>ORA-07445 errors found in alert log</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2923</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
  fi   
else
  resultSet=${resultSet}"<RESULT><STATUS>EFAIL</STATUS><ROW_ID>$instance_id</ROW_ID><EXEC_ERROR>Error while checking for ORA-07445 errors in alert log</EXEC_ERROR><TRACE>Error while checking for ORA-07445 errors in alert log</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>2924</ID><MSG_DATA><DATA>$instance_id</DATA></MSG_DATA></NLS_MSG></RESULT>"
fi   


resultSet=${resultSet}"</RESULTSET>"

echo $resultSet
exit $exitStatus
