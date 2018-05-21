#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checktmpfs.sh /main/9 2013/09/16 17:27:41 mpradeep Exp $
#
# checktmpfs.sh
#
# Copyright (c) 2011, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      checktmpfs.sh - Checking whether /dev/shm is mounted as tmpfs
#
#    DESCRIPTION
#      Pluggable verification framework shell script to check for /dev/shm mounted
#      
#    NOTES
#      Checks whether /dev/shm is mounted and checks for an /etc/fstab
#      entry if it is readable. Note: on SuSE systems the /etc/fstab entry is NOT
#      required so this is NOT a failure case.
#      
#    SYNTAX:
#      $checktmpfs.sh [required_size]
#      can be called without argument, or required size as zero integer
#      for example,
#      $checktmpfs.sh 0 or $checktmpfs.sh are same
#      whereas, 
#      $checktmpfs.sh 2048 OR $checktmpfs.sh 45222 specify the valid required_value argument 
#
#    MODIFIED   (MM/DD/YY)
#    mpradeep    09/13/13 - 17371426 - Correct Syntax error
#    kfgriffi    06/20/13 - Add support for tmpfs size using % char(bug16958130)
#    ptare       08/28/12 - Fix Bug#14177769 complete overhaul
#    kfgriffi    03/23/12 - Fix bug 13716594
#    narbalas    02/11/11 - Creation
#
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin

MOUNT="mount"
SGREP="grep"
ECHO="echo"
FREE="free"
SAWK="awk"
SED="sed"
LS="ls"
DF="df"
FSTAB=/etc/fstab
REQUIRED_SIZE=$1

#Internal function to initialize message strings
updateMessages()
{
  SUCCESSMSG1="<RESULT>SUCC</RESULT><EXPECTED>true</EXPECTED><COLLECTED>true</COLLECTED><TRACE>Check for /dev/shm mounted is enabled passed on node $HOST</TRACE>"
  SUCCESSMSG2="<RESULT>SUCC</RESULT><EXPECTED>$REQUIRED_SIZE</EXPECTED><COLLECTED>$SIZE_CURRENT</COLLECTED><TRACE>Check for /dev/shm mounted is enabled passed on node $HOST</TRACE>"
  ERRMSG1="<RESULT>VFAIL</RESULT><EXPECTED>true</EXPECTED><COLLECTED>false</COLLECTED><TRACE>Check for /dev/shm mounted enabled failed on node $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0420</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
  ERRMSG2="<RESULT>VFAIL</RESULT><EXPECTED>true</EXPECTED><COLLECTED>false</COLLECTED><TRACE>Check failed on node $HOST, entry for /dev/shm is missing inside $FSTAB</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0421</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
  ERRMSG3="<RESULT>WARN</RESULT><EXPECTED>$SIZE_CURRENT</EXPECTED><COLLECTED>$SIZE_REBOOT</COLLECTED><TRACE>Check failed on node $HOST, value configured in /etc/fstab is $SIZE_REBOOT MB and is different compared to current size of $SIZE_CURRENT MB with which the memory disk is mounted</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0422</ID><MSG_DATA><DATA>$SIZE_CURRENT</DATA><DATA>$SIZE_REBOOT</DATA></MSG_DATA></NLS_MSG>"
  ERRMSG4="<RESULT>EFAIL</RESULT><EXPECTED>true</EXPECTED><COLLECTED>false</COLLECTED><TRACE>Check failed on node $HOST, $FSTAB file does not exist</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0423</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
  ERRMSG5="<RESULT>VFAIL</RESULT><EXPECTED>$REQUIRED_SIZE</EXPECTED><COLLECTED>$SIZE_CURRENT</COLLECTED><TRACE>Check failed on node $HOST, The current mount size of /dev/shm temporary file system is $SIZE_CURRENT MB which is less than that of required size $REQUIRED_SIZE MB</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0426</ID><MSG_DATA><DATA>$SIZE_CURRENT</DATA><DATA>$REQUIRED_SIZE</DATA><<DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
  ERRMSG6="<RESULT>EFAIL</RESULT><EXPECTED>true</EXPECTED><COLLECTED>false</COLLECTED><TRACE>Check failed on node $HOST, Could not retrieve the current size of /dev/shm mounted</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0427</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
}

errorout()
{
  exit 1
}

exitSucc() 
{
  exit 0
}

#Internal method to convert the size variable into integer representing it
#in megabytes. However the input values may take the form of:
#
#    nnnM - nnn specified as Megabytes
#    nnnm - nnn specified as Megabytes
#    nnnG - nnn specified as Gigabytes
#    nnng - nnn specified as Gigabytes
#    nnn% - nnn specified as a percentage of RAM memory on the system
#
#Example if the system has 12400 Megabytes of RAM, and the value passed 
#in is 75%, then the conversion should return a value of 9300.
#
#The converted integer value is saved in variable RETURN_VALUE
convertSizeToMB()
{
  INPUT_UNIT=$1
  INT_UNIT=0;
  if [ -n "$INPUT_UNIT" ]
  then
    if [[ "$INPUT_UNIT" == *M* ]]
    then
       INT_UNIT=`$ECHO $INPUT_UNIT | ${SAWK} -FM '{print $1}'`
    elif [[ "$INPUT_UNIT" == *m* ]]
    then
       INT_UNIT=`$ECHO $INPUT_UNIT | ${SAWK} -Fm '{print $1}'`
    elif [[ "$INPUT_UNIT" == *G* ]]
    then
       INT_UNIT=`$ECHO $INPUT_UNIT | ${SAWK} -FG '{print $1}'`
       INT_UNIT=`expr $INT_UNIT \* 1024`
    elif [[ "$INPUT_UNIT" == *g* ]]
    then
       INT_UNIT=`$ECHO $INPUT_UNIT | ${SAWK} -Fg '{print $1}'`
       INT_UNIT=`expr $INT_UNIT \* 1024`
    elif [[ "$INPUT_UNIT" == *%* ]]
    then
       # The fstab entry can be expressed in the form of a percentage of RAM 
       # memory (e.g. 50%, 75%, etc...). If this is the case then we need to
       # get the size of RAM
       RAM_MEM_SIZE=`${FREE} -m | ${SGREP} 'Mem:' | ${SAWK} '{ print $2 }'`

       # First strip off the '%' sign from the end of the value and save
       INT_UNIT=`$ECHO $INPUT_UNIT | ${SAWK} -F% '{print $1}'`

       # Now convert the integer value into a divisor.
       # Note: we have to use the 'bc' utility to make sure we get correct
       #       values.
       DIVIDER=$($ECHO "scale=10; 100 / ${INT_UNIT}" | bc)

       # Finally divide the amount of RAM memory by the divisor to obtain 
       # the value we will be looking for /DEV/SHM
       INT_UNIT=$($ECHO " ${RAM_MEM_SIZE} / ${DIVIDER} " | bc)
    else
       INT_UNIT=$INPUT_UNIT
    fi
  fi
  RETURN_VALUE=$INT_UNIT
}

#Internal function to parse the size unit string to retrieve size in MB, and compare the units
#must be called with 2 arguments, first argument being current size and second argument being required size or size to compare with
#returns 0 if current size is greater than or equal to required size
#returns 1 if current size is less than required size 
compareMountSize()
{
  INPUT_UNIT1=$1
  INPUT_UNIT2=$2
  INT_UNIT1=0;
  INT_UNIT2=0;
  if [ -n "$INPUT_UNIT1" ] && [ -n "$INPUT_UNIT2" ]
  then
    convertSizeToMB $INPUT_UNIT1
    INT_UNIT1=$RETURN_VALUE
    convertSizeToMB $INPUT_UNIT2
    INT_UNIT2=$RETURN_VALUE

    if [ $INT_UNIT1 -ge $INT_UNIT2 ]
    then
        return 0
    else
        return 1
    fi
  fi
}

#Internal function to check for the consistency of current /dev/shm size with an entry inside fstab file
checkSizeConsistencyWithFstab()
{
    FSTAB_DEV_SHM_ENTRY=`${SGREP} '^tmpfs' ${FSTAB} | ${SGREP} '/dev/shm'`
    #Check if /dev/shm entry is present inside fstab file
    if [ -n "$FSTAB_DEV_SHM_ENTRY" ]
    then
       #Get the configured size of /dev/shm mount inside the fstab file
       SIZE_REBOOT=`${ECHO} ${FSTAB_DEV_SHM_ENTRY} | ${SAWK} '{ print $4 }' | awk -F= '{ print $2 }'`

       # Now that we have the value from /etc/fstab, convert it to MB if its
       # a numeric value, or if it is a percentage get the percentage of RAM
       convertSizeToMB $SIZE_REBOOT
       SIZE_REBOOT=$RETURN_VALUE

       #If we have retrieved the reboot size then lets compare it with that of current size
       if [ -n "$SIZE_REBOOT" ]
       then 
          #Check if the reboot size and current size are equal
          compareMountSize $SIZE_REBOOT $SIZE_CURRENT
          if [ $? -eq 0 ]
          then
              # Task Success
              ${ECHO} ${SUCCESSMSG}
              exitSucc 
          else
              updateMessages
              ${ECHO} ${ERRMSG3}
              exitSucc 
          fi
       else
          #The fstab file does not define size configured, skip the check fir configured value inside fstab
          ${ECHO} ${SUCCESSMSG}
          exitSucc
       fi
     else
        # On SuSE?
        SUSERELEASE=`${LS} /etc | ${SGREP} -i suse | ${SGREP} -i release`
        SUSERELEASE_FILE="/etc/$SUSERELEASE"

        # On NOVELL?
        NOVELLRELEASE=`${LS} /etc | ${SGREP} -i novell | ${SGREP} -i release`
        NOVELLRELEASE_FILE="/etc/$NOVELLRELEASE"

        # On SLES? (not used yet, here for completeness)
        SLESRELEASE=`${LS} /etc | ${SGREP} -i sles | ${SGREP} -i release`
        SLESRELEASE_FILE="/etc/$SLESRELEASE"

        # on SuSE 11, or greater, /dev/shm does not need to be in /etc/fstab
        if [ -f $SUSERELEASE_FILE ]
        then
            # Get release major ver (i.e. if 11.1 get 11)
            RELEASE_VER=`/bin/rpm -q --qf "%{VERSION}" sles-release | cut -f 1 -d '.'`
            if [ $RELEASE_VER -gt 10 ]
            then
                # Task Success - /dev/shm does not need to be in /etc/fstab on SuSE
                ${ECHO} ${SUCCESSMSG}
                exitSucc
            fi
        fi

        if [ -f $NOVELLRELEASE_FILE ]
        then
            # Task Success - /dev/shm does not need to be in /etc/fstab for NOVELL
            ${ECHO} ${SUCCESSMSG}
            exitSucc
        fi

        # There was no entry found in /etc/fstab, report this error.
        ${ECHO} ${ERRMSG2}
        errorout 
    fi
}

#Script execution begins here
updateMessages

#Assume the success message to be default first
SUCCESSMSG=$SUCCESSMSG1

#First, check the results from running /bin/mount to see if /dev/shm is mounted
RSLTMOUNT=`${MOUNT} | ${SGREP} '^tmpfs' |  ${SGREP} '/dev/shm'`
RET=$?
if [ $RET -ne 0 ]
then
    #/dev/shm not mounted
    ${ECHO} ${ERRMSG1}
    errorout
fi

#Get the current size of mounted /dev/shm with its unit, i.e 7900M or 8G or 8500m or 50% etc
SIZE_ELEM=`${ECHO} ${RSLTMOUNT} | ${SAWK} '{ print $6 }' | ${SAWK} -Fsize= '{ print $2 }' | ${SAWK} -F\) '{print $1}'`
if [ -z "$SIZE_ELEM" ]
then
   #fallback on the df approach
   SIZE_CURRENT=`${DF} -h |  ${SGREP} 'tmpfs' |  ${SGREP} '/dev/shm' | ${SAWK} '{ print $2 }'`
else
   # We are not expecting the 'mount' command to return a percentage value,
   # but to be sure use the conversion subroutine to check it.
   convertSizeToMB $SIZE_ELEM
   SIZE_CURRENT=$RETURN_VALUE
fi

#Check if we have the current size of /dev/shm retrieved
if [ -z "$SIZE_CURRENT" ]
then 
    #Current size of /dev/shm mounted could not be retrieved on this node, report error
    ${ECHO} ${ERRMSG6}
    errorout
fi

#Convert the current size in MB's
convertSizeToMB $SIZE_CURRENT
SIZE_CURRENT=$RETURN_VALUE

#Check if we are asked to check the required size
if [ -n "$REQUIRED_SIZE" ]
then
    convertSizeToMB $REQUIRED_SIZE
    REQUIRED_SIZE=$RETURN_VALUE
fi

#Call update messages to update the messages with current size
updateMessages

# If required value is specified and is greater than zero then
# check if the current size is greater than or equal to the required size
# if we are asked to check it
if [ -n "$REQUIRED_SIZE" ] && [[ "$REQUIRED_SIZE" != 0* ]]
then 
    SUCCESSMSG=$SUCCESSMSG2
    compareMountSize $SIZE_CURRENT $REQUIRED_SIZE
    if [ $? -eq 1 ]
    then
       ${ECHO} ${ERRMSG5}
       errorout
    else
       SUCCESSMSG=$SUCCESSMSG2
    fi
fi 

#Check whether mount information is available at startup in /etc/fstab if /etc/fstab exists and is readable 
if [ -f $FSTAB ]
then
    #Check if the fstab file is readable
    if [ -r $FSTAB ]
    then
        #/etc/fstab is readable, lets verify the consistency of /dev/shm mount size inside the entry in /etc/fstab file
        checkSizeConsistencyWithFstab
    else
        #if /etc/fstab is not readable we do not verify the /dev/shm entry inside it, hence report success and leave
        ${ECHO} ${SUCCESSMSG}
        exitSucc
    fi
else
    #/etc/fstab file does not exist on this node, report error
    ${ECHO} ${ERRMSG4}
    errorout 
fi

