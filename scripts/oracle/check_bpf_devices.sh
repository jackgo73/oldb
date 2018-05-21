#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_bpf_devices.sh /st_has_12.1/1 2014/04/09 00:03:19 ptare Exp $
#
# check_bpf_devices.sh
#
# Copyright (c) 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      check_bpf_device.sh - check the Berkeley Packet Filter devices setting
#                            for cluster HAIP 
#
#    DESCRIPTION
#      check the Berkeley Packet Filter Devices "/dev/bpf*" file's existence
#      and sanity of its major and minor numbers 
#
#    NOTES
#      Currently this check only applies to AIX releases 
#
#    MODIFIED   (MM/DD/YY)
#    ptare       03/21/14 - Fix Bug#18432257 check for the Berkeley packet
#                           filter devices on AIX
#    ptare       03/21/14 - Creation
#
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
SECHO="echo"
SGREP="grep"
SAWK="awk"
SLIST_FILES="ls"
BPF_DEVICE_PATH="/dev/bpf*"
MAJOR_NUMBER=-1
MINOR_NUMBER=-1
BPF_DEVICE_EXIST="FALSE" #Assume false to begin with
HAS_DUPLICATE_MAJOR_NUMBER="FALSE" #Flag to indicate if duplicates are present
BPF_ENTRY_SEPARATOR=" "
BPF_DUP_DEVICELIST_SEPARATOR=":"
DEVICE_LIST_SEPARATOR=","
MAJOR_MINOR_NUMBER_SEPARATOR="|"
_HOST=`/bin/hostname`

#The following variable ALL_BPF_DEVICE_LIST maintains the list
#of all bpf devices with devices which duplicate the major number of bpf device
#The list maintains the data in following form
#/dev/bpf0[MAJOR#|MINOR#]:/dev/root,/dev/xvda /dev/bpf2[MAJOR#|MINOR#]:/dev/sgd,/dev/mpt and so on.......
ALL_BPF_DEVICE_LIST=""

# Set default exit status to indicate success.
exitstatus=0

#method to report the outcome and return with exit status
report_and_exit ()
{
  $SECHO $result
  exit $exitstatus
}

#utility method to get the major and minor number of given device file
getMajorMinorNumber ()
{
  device=$1
  MAJOR_NUMBER=`$SLIST_FILES -l $device | $SAWK '{print $5}' | $SAWK -F"," '{print $1}'`
  MINOR_NUMBER=`$SLIST_FILES -l $device | $SAWK '{print $6}'`
}

#Method to check if the major number of bpf devides is duplicate of any other device
#This method updates the following global variable list
#ALL_BPF_DEVICE_LIST if any duplicating major number devices are found
#In addition, this method sets variable HAS_DUPLICATE_MAJOR_NUMBER to true
#if any duplicating major number devices are found.
#The variable ALL_BPF_DEVICE_LIST 
#maintains the list in following form
#/dev/bpf0:/dev/root,/dev/xvda /dev/bpf2:/dev/sgd,/dev/mpt and so on.......
isMajorNumberDuplicate ()
{
  major=$1
  minor=$2
  bpfDevice=$3
  LIST_OF_DUPLICATE_MAJOR_NUMBER=""
  allMajorNumberDuplicatingDevices=`$SLIST_FILES -l /dev/ 2>/dev/null | $SGREP -E '^c|^b' | $SAWK '{print $5, "/dev/"$10}' | $SGREP ^$major, | $SAWK '{print $2}'`

  ret=$?
  if [ $ret -ne 0 ]; then
    #Seems like there is a failure in device list retrieval
    result="<RESULT>EFAIL</RESULT><TRACE>Failed to list the devices under /dev/ directory on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0476</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
    exitstatus=$ret
    report_and_exit
  else
    #process the device list to report the device
    #which matches this major number. i.e major number duplication

    for devPath in $allMajorNumberDuplicatingDevices
    do
      #Major number is duplicated by this device. lets check if this is not a 
      #BPF device and report accordingly
      allBPFDevices=`$SLIST_FILES $BPF_DEVICE_PATH`
      isBPFDevice="FALSE"
      for bpfDevPath in $allBPFDevices
      do
        if [ $bpfDevPath == $devPath ]
        then
          isBPFDevice="TRUE"
        fi
      done

      #If the duplicating device is bpf device then it is expected so ignore
      if [ $isBPFDevice == "FALSE" ]
      then
        if [ "$LIST_OF_DUPLICATE_MAJOR_NUMBER" == "" ]
        then
          LIST_OF_DUPLICATE_MAJOR_NUMBER=$devPath
        else
          LIST_OF_DUPLICATE_MAJOR_NUMBER=$LIST_OF_DUPLICATE_MAJOR_NUMBER$DEVICE_LIST_SEPARATOR$devPath
        fi
      fi
   done

    #Check to see if we have duplication of major number
    if [ "$LIST_OF_DUPLICATE_MAJOR_NUMBER" != "" ]
    then
      #We have some device which duplicates the major number 
      #of this bpf device, this must be reported
      bpfDeviceStr=$bpfDevice[$major$MAJOR_MINOR_NUMBER_SEPARATOR$minor]$BPF_DUP_DEVICELIST_SEPARATOR$LIST_OF_DUPLICATE_MAJOR_NUMBER
      HAS_DUPLICATE_MAJOR_NUMBER="TRUE"
    else
      bpfDeviceStr=$bpfDevice[$major$MAJOR_MINOR_NUMBER_SEPARATOR$minor]
    fi

    #Update the BPF device list
    if [ "$ALL_BPF_DEVICE_LIST" == "" ]
    then
      ALL_BPF_DEVICE_LIST=$bpfDeviceStr
    else
      ALL_BPF_DEVICE_LIST=$ALL_BPF_DEVICE_LIST$BPF_ENTRY_SEPARATOR$bpfDeviceStr
    fi

  fi
}

#method to check if the Berkeley packet filter devices are created.
#If found created then retrieve their major and minor numbers
CheckBPFDevices ()
{
  #list all the bpf devices under /dev/ directory by issuing `ls -l /dev/bpf*`
  allBPFDevices=`$SLIST_FILES $BPF_DEVICE_PATH 2>/dev/null`
  ret=$?
  if [ $ret -ne 0 ]; then
    #Seems like the bpf devices are not yet created, set the flag and we are done 
    BPF_DEVICE_EXIST="FALSE"
  else
    #We found one or more bpf devices under /dev/ directory, now lets collect
    #their major and minor numbers
    BPF_DEVICE_EXIST="TRUE"
    for filepath in $allBPFDevices
    do
      getMajorMinorNumber $filepath
      currentBPFMajorNumber=$MAJOR_NUMBER
      currentBPFMinorNumber=$MINOR_NUMBER
      isMajorNumberDuplicate $currentBPFMajorNumber $currentBPFMinorNumber $filepath
    done
  fi
}


#EXECUTION STARTS HERE
#First check if the Berkeley packet filter devices bpf* are created and 
#available on this node
CheckBPFDevices

if [ $BPF_DEVICE_EXIST == "TRUE" ]
then
  #Do the reporting based on BPF devices duplication of major number
  if [ "$HAS_DUPLICATE_MAJOR_NUMBER" == "FALSE" ]
  then
    result="<RESULT>SUCC</RESULT><COLLECTED>$ALL_BPF_DEVICE_LIST</COLLECTED><EXPECTED></EXPECTED><TRACE>Berkeley packet filter devices are created correctly on node $_HOST</TRACE>"
  else
    result="<RESULT>WARN</RESULT><COLLECTED>$ALL_BPF_DEVICE_LIST</COLLECTED><EXPECTED></EXPECTED><TRACE>Berkeley packet filter devices use duplicate major number on node $_HOST</TRACE>"
  fi
else
  #There is no BPF device created yet. The user must create one and hence report failure
  result="<RESULT>VFAIL</RESULT><TRACE>The Berkeley packet filters devices are not found at /dev/bpf*</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0474</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"  
fi

report_and_exit


