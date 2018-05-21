#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checkmemlock.sh /st_has_12.1/1 2014/06/03 02:50:14 ptare Exp $
#
# checkmemlock.sh
#
# Copyright (c) 2010, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      checkmemlock.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      A script to validate whether max. memory locked limit is less than a certain value
#      Consumed by the pluggable framework as a Pluggable Task.
#
#    NOTES
#
#    MODIFIED   (MM/DD/YY)
#    ptare       06/01/14 - XbranchMerge ptare_bug-17276570 from main
#    ptare       05/21/14 - Fix Bug#17276570 correct the expected value to be
#                           90% of total RAM if hugepages are enabled
#    ptare       06/05/13 - Correct the retrieval and comparision
#    ptare       02/14/12 - fix Bug#11785435
#    narbalas    05/07/10 - Fix Expected Value
#    narbalas    04/22/10 - Creation
#

#This function checks if hugepages are supported and enabled if supported
checkHugePagesSupportedAndEnabled()
{
PHYSMEM=`$CAT /proc/meminfo | $GREP MemTotal | $AWK '{print $2}'`
ret=$?
if [ $ret -eq 0 ]
then
    #Since the decision to check for enabled hugepages only depends on whether the system has 4GB or more 
    #Physical memory unit is kB. Required memory is calculated in kB (4 GB = 4 * 1048576 kB)
    REQMEM=`expr $REQMEMSIZE \* 1048576`
else
    #Command Failure - Failed to get physical memory
    ERRCODE=4
    prepareResult
    adieu
fi 

#Check if installed physical memory is greater than 4GB
if [ $PHYSMEM -ge $REQMEM ]
then
  #installed memory is more than 4GB
  #check if hugepages are supported and enabled 
  CHECKHUGEPAGES=`$GREP Hugepage /proc/meminfo`
  ret=$?
  if [ $ret -eq 0 ]
  then
    #Huge pages feature is supported on this system, lets check if it is enabled.
    if [ -f $HUGEPAGEPATH ]
    then
      #Huge pages feature is enabled
      HUGEPAGES_ENABLED="TRUE"
    fi
  fi
fi
}

#Checks whether automatic memory management is enabled
checkAMMEnabled()    
{
$MOUNT | $GREP shm | $GREP ramfs >/dev/null 2>&1
if [ $? -eq 0 ]
then
    AMM_ENABLED="TRUE"
else
    #Flag that AMM is not enabled (ERRCODE = 1)
    AMM_ENABLED="FALSE"
fi
}

#Check maximum locked memory setting
checkMemLock()
{

if [ "${CVU_TEST_ENV}" = "true" ]; then
     VAL=$EXPECTED
     ERRCODE=0
     return
fi

$GREP "memlock" $LIMITSDOTCONF | $GREP -v "^#" | $GREP hard >/dev/null 2>&1
if [ $? -eq 0 ];
then
    #Check if we have the user name entry made inside the limits conf file
    VAL=`$GREP "memlock" $LIMITSDOTCONF | $GREP -v "^#" | $GREP "^[[:space:]]*\$CURUSR " | $GREP 'hard' | $HEAD -n 1 | $AWK '{ print $4 }' 2>&1`
    if [ "$VAL" = "" ]; then
      #Get the default entry if existing
      VAL=`$GREP "memlock" $LIMITSDOTCONF | $GREP -v "^#" | $GREP "^[[:space:]]*\*" | $GREP 'hard' | $HEAD -n 1 | $AWK '{ print $4 }' 2>&1`
    fi;

    #Check if we still do not have the value
    if [ "$VAL" = "" ]; then
      ERRCODE=2
      return
    fi;

    #if the value is unlimited OR equal to expected or greater than expected then it is success
    if [ "$VAL" = "unlimited" ] || [ $VAL -eq $EXPECTED ] || [ $VAL -gt $EXPECTED ] ;
    then
       #SUCCESS
       ERRCODE=0
       return
    else
       #FAILURE
       ERRCODE=1
       return
    fi
else
    ERRCODE=2
    return
fi
}

setupEnv()
{
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
#use absolute paths for all the commands
CAT="/bin/cat"
GREP="/bin/grep"
AWK="/bin/awk"
HUGEPAGEPATH="/proc/sys/vm/nr_hugepages"
REQMEMSIZE=4
HOST=`/bin/hostname`
CHECKHUGEPAGES=0
VAL=0
LIMITSDOTCONF="/etc/security/limits.conf"
ERRCODE=9
CURUSR=`/usr/bin/whoami`
HEAD="/usr/bin/head"
HUGEPAGES_ENABLED="FALSE"
MOUNT="/bin/mount"
AMM_ENABLED="FALSE"

#Check whether Automatic Memory Management is enabled
checkAMMEnabled

#Assume the default expected value
EXPECTED=3145728

#Check if hugepages are enabled
checkHugePagesSupportedAndEnabled

if [ "$HUGEPAGES_ENABLED" = "TRUE" ]; then
  #Huge pages are enabled and hence calculate
  #the expected minimum value of memlock
  #based on currently installed Physical memory size
  #We expect a minimum 90% of the total RAM
  #size to be set to memlock

  if [ "$PHYSMEM" != "" ]; then
    #Calculate the 90% of it
    LESS=`expr $PHYSMEM / 10`
    EXPECTED=`expr $PHYSMEM - $LESS`
  fi;
fi;

}

prepareResult()
{
 case $ERRCODE in
       0)
          RESULT="<RESULT>SUCC</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check for maximum memory locked limit passed on node $HOST</TRACE>"
          ;;
       1)
          #Frame the verification failure message based on the current environment
          if [ "$AMM_ENABLED" = "TRUE" ]; then
            RESULT="<RESULT>VFAIL</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check failed on node $HOST, Maximum locked memory limit is less than $EXPECTED when DB Automatic Memory Management feature is enabled</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0042</ID><MSG_DATA><DATA>$EXPECTED</DATA><DATA>$VAL</DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          else
            if [ "$HUGEPAGES_ENABLED" = "TRUE" ]; then
              RESULT="<RESULT>VFAIL</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check failed on node $HOST, Maximum locked memory limit is less than $EXPECTED when huge pages are enabled</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0068</ID><MSG_DATA><DATA>$EXPECTED</DATA><DATA>$VAL</DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
            else
              RESULT="<RESULT>VFAIL</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check failed on node $HOST, Maximum locked memory limit is less than $EXPECTED</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0067</ID><MSG_DATA><DATA>$EXPECTED</DATA><DATA>$VAL</DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
            fi;
          fi;
          ;;
       2)
          RESULT="<RESULT>VFAIL</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check failed on node $HOST, no values set for Maximum locked memory</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0044</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       4)
          RESULT="<RESULT>WARN</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><EXEC_ERROR>Error while getting physical memory of the system</EXEC_ERROR><TRACE>Unable to get the physical memory of the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0022</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       9) RESULT="<RESULT>EFAIL</RESULT><EXPECTED>$EXPECTED</EXPECTED><COLLECTED>$VAL</COLLECTED><TRACE>Check for maximum memory locked limit when DB Automatic memory management feature is enabled encountered a command failure </TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0043</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
  esac
  return
}

adieu()
{
  echo $RESULT
  exit 
}

#Main
#Setup environment
setupEnv
checkMemLock
prepareResult
adieu



