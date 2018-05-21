#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/getASMDiskInfo.sh /main/1 2012/12/17 10:41:18 spavan Exp $
#
# getASMDiskInfo.sh
#
# Copyright (c) 2012, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      getASMDiskInfo.sh - gets discovery string and whether it is the default discovery string
#
#    DESCRIPTION
#      gets ASM discovery string and whether it is default discovery string
#
#    NOTES
#      works with pre-11.2 (i.e. 10.2 and 11.1) ASM instances.
#
#    MODIFIED   (MM/DD/YY)
#    spavan      11/28/12 - execute sql statement on ASM instance
#    spavan      11/28/12 - Creation
#
ECHO=echo
GREP=/bin/grep

if [ $# -lt 4 ];
then
   $ECHO "Usage $0 <ASM_SID> <ASM_HOME> <PATH_TO_SPOOL_FILE> <PATH_TO_SQL_FILE>"
   exit 1
fi

ORACLE_SID=$1
export ORACLE_SID
ORACLE_HOME=$2
export ORACLE_HOME
SPOOL_FILE=$3
SQL_FILE_DIR=$4
# 10.2 doesn't have sysasm role so use sysdba 
$ORACLE_HOME/bin/sqlplus "/ as sysdba" @$SQL_FILE_DIR/ASMDiskInfo.sql $SPOOL_FILE > /dev/null 2>&1
$ECHO "<CV_ORA_ERR>"
$GREP "ORA-" $SPOOL_FILE 
if [ $? -eq 0 ]
then
   EXIT_VALUE=1
else
   EXIT_VALUE=0
fi

$ECHO "</CV_ORA_ERR>"
exit $EXIT_VALUE
