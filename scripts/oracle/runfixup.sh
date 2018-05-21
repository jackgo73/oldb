#!/bin/sh
#
# $Header: opsm/cvutl/runfixup.sh /main/16 2012/11/13 21:44:52 ptare Exp $
#
# runfixup.sh
#
# Copyright (c) 2007, 2012, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      runfixup.sh - This script is used to run fixups on a node
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    ptare       11/09/12 - retrieve fixup information from fixup input file
#    dsaggi      09/11/12 - Fix 14612018 -- Qualify path for dirname
#    ptare       03/13/12 - enhance the output of the script to make it more user friendly instead of displaying exectask tags
#    ptare       05/19/11 - Make changes for fixup project
#    agorla      08/18/10 - bug#10023742 - donot echo id cmd
#    nvira       05/04/10 - fix the id command
#    dsaggi      01/27/10 - Fix 8729861
#    nvira       06/24/08 - remove sudo
#    dsaggi      05/29/08 - remove orarun.log before invocation
#    dsaggi      10/24/07 - Creation
#
AWK=/bin/awk
SED=/bin/sed
ECHO=/bin/echo
ID=/usr/bin/id
GREP=/bin/grep
DIRNAME=/usr/bin/dirname
FIXUP_INPUT_FILE=fixup.conf
FIXUP_INPUT_FILE_PATH=`$DIRNAME $0`/fixup/$FIXUP_INPUT_FILE

#internal method to initialize the fixup instructions from the input file
initializeFixupInstructions()
{ 
  if [ -f $FIXUP_INPUT_FILE_PATH ]
  then
     FIXUP_DATA_FILE=`$GREP FIXUP_DATA_FILE $FIXUP_INPUT_FILE_PATH | cut -d '=' -f 2`
     FIXUP_TRACE_LEVEL=`$GREP FIXUP_TRACE_LEVEL $FIXUP_INPUT_FILE_PATH | cut -d '=' -f 2`
  else
     $ECHO " "
     $ECHO "ERROR: "
     $ECHO "Fixup instructions are not yet generated for this node."
     exit 1
  fi
} 

#initialize the fixup instructions from the fixup input file
initializeFixupInstructions

RUID=`$ID -u 1> /dev/null 2>&1`
status=$?

if [ "$status" != "0" ];
then
  RUID=`$ID | $AWK -F\( '{print $1}' | $AWK -F= '{ print $2}'`
else
RUID=`$ID -u`
fi

if [ -z "$RUID" ];
then
  $ECHO " "
  $ECHO "ERROR: "
  $ECHO "Failed to get effective user id."
  exit 1
fi 

if [ "${RUID}" != "0" ];then
  $ECHO " "
  $ECHO "ERROR: "
  $ECHO "You must be logged in as root (uid=0) when running $0."
  exit 1
fi

EXEC_DIR=`$DIRNAME $0`
RMF="/bin/rm -f"

if [ "X$FIXUP_DATA_FILE" = "X" ]
then
  $ECHO " "
  $ECHO "ERROR: "
  $ECHO "fixup instructions are not yet generated for this node."
  exit 1
else

$RMF ${EXEC_DIR}/cvu_fixup_trace_*.log

if [ "X$FIXUP_TRACE_LEVEL" = "X" ]
then
FIXUP_TRACE_OPTION=
else
FIXUP_TRACE_OPTION="-tracelevel $FIXUP_TRACE_LEVEL"
fi

# Execute the exectask 
EXECTASK_OUTPUT=`${EXEC_DIR}/exectask.sh -runfixup $FIXUP_DATA_FILE $FIXUP_TRACE_OPTION 2>&1`
status=$?

if [ "$status" != "0" ];
then
  $ECHO " "
  $ECHO "FAILED: Fix-up operations could not be completed on this node. "
#Extract the exectask error details from the CV_ERR TAGS
  EXECTASK_ERROR=`$ECHO $EXECTASK_OUTPUT | $SED "s/<CV_ERR>//;s/<\/CV_ERR>.*//"`
#Check if we have the exectask error, if yes then print it 
if [ "X$EXECTASK_ERROR" != "X" ]
then
  $ECHO " "
  $ECHO "ERROR: "
  $ECHO $EXECTASK_ERROR
  $ECHO " "
fi
else
  $ECHO "All Fix-up operations were completed successfully."
fi
fi

