#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/checkramfs.sh /main/3 2011/01/12 18:13:46 nvira Exp $
#
# checkramfs.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checkramfs.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      Checks whether DB Automatic Memory Management is enabled and
#      Consumed by the pluggable framework as a pluggable task as a
#      VAR_TASK (conditional task)
#
#    NOTES
#
#    MODIFIED   (MM/DD/YY)
#    narbalas    04/22/10 - Initial Version
#    narbalas    04/22/10 - Creation
#

checkRamFS()	
{
$MOUNT | $GREP shm | $GREP ramfs >/dev/null 2>&1
if [ $? -eq 0 ]
then
    return
else
    #Flag that AMM is not enabled (ERRCODE = 1)
    ERRCODE=1
    prepareResult
    adieu
fi
}

checkRamFSPerms()
{
RSLT=`$STAT -c "%a" /dev/shm 2>&1`
if [ $? -eq 0 ]
then 
    if [ $RSLT=="755" ]
    then
        ERRCODE=0
        return
    else
        #Flag that RAMFS perms are not 755 (ERRCODE=2)
        ERRCODE=2
        return
    fi
else
    ERRCODE=9  
     return
fi
}

prepareResult()
{
case $ERRCODE in
       0)
          RESULT="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><TRACE>Check for DB Automatic Memory Management enabled passed on node $HOST</TRACE>"
          ;;
       1)
          RESULT="<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><TRACE>Check failed on node $HOST, Automatic Memory Management is not enabled</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0040</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       2)
          RESULT="<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><TRACE>Check failed on node $HOST, permissions for ramfs are not 0755 </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0041</ID><MSG_DATA><DATA>$HOST</DATA><DATA>/etc/security/limits.conf</DATA></MSG_DATA></NLS_MSG>"
          ;;
       9) 
          RESULT="<RESULT>UNKNOWN</RESULT><COLLECTED>false</COLLECTED><TRACE>Check for  DB Automatic memory management  is enabled encountered an unknown failure </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0044</ID><MSG_DATA><DATA>$HOST</DATA><DATA>/etc/security/limits.conf</DATA></MSG_DATA></NLS_MSG>"          ;;
  esac
  return
}

adieu()
{
  echo $RESULT
  exit $ERRCODE
}

#Main - Script execution starts here
#Setup Environment
GREP=/bin/grep
LS=/bin/ls
AWK=/bin/awk
CAT=/bin/cat
MOUNT=/bin/mount
ERRCODE=9
STAT=/usr/bin/stat
HOST=`/bin/hostname`
#Call functions
checkRamFS
checkRamFSPerms
prepareResult
adieu
