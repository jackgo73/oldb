#!/bin/sh
#
# Copyright (c) 2004, 2013, Oracle and/or its affiliates. All rights reserved. 

# Build: 110804

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PATH

DIRNAME=`dirname $0`

# checks if ORA_CRS_HOME has not been set
if [ -n "$ORA_CRS_HOME" ]
then 
   ORA_CRS_HOME=
   export ORA_CRS_HOME
fi

if [ "-getver" = "$1" ]
 then
  EXECTASK_OUT_FILE="$DIRNAME/exectask.$$.out"
  $DIRNAME/exectask "$@" > $EXECTASK_OUT_FILE 2>&1
  EXIT_STATUS=$?
  out=`cat $EXECTASK_OUT_FILE`
  if [ "$EXIT_STATUS" = "0" ]
   then
    echo $out
   else
    echo "<CV_CMD>$0 $@</CV_CMD><CV_VAL>$out</CV_VAL><CV_ERES>$EXIT_STATUS</CV_ERES><CV_ERR></CV_ERR>"
  fi
  rm -rf $EXECTASK_OUT_FILE
else
  exec $DIRNAME/exectask "$@" 
fi
