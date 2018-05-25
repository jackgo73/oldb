#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/checkhugepage.sh /st_has_12.1/1 2014/06/03 02:50:14 ptare Exp $
#
# checkhugepage.sh
#
# Copyright (c) 2009, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      checkhugepage.sh - Check whether hugepages are set if available memory is >= 4GB 
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    ptare       06/01/14 - XbranchMerge ptare_bug-17276570 from main
#    ptare       05/22/14 - correct the display of result
#    ptare       12/17/13 - Fix Bug#17800647 do not report failure when
#                           hugepages are not supported
#    ptare       06/25/13 - Add -fixup option
#    maboddu     02/21/13 - Correct the expression for checking the available
#                           memroy
#    nvira       09/29/10 - set expected value
#    narbalas    05/06/10 - Fix script to ensure correct execution for tests
#    shmubeen    12/29/09 - check whether hugepages are set or not if available
#                           memory is >= 4GB
#    shmubeen    12/29/09 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SCAT="cat"
SGREP="grep"
SAWK="awk"
HUGEPAGEPATH="/proc/sys/vm/nr_hugepages"
TRANSPARENTHUGEPAGEPATH="/sys/kernel/mm/transparent_hugepage/enabled"
REQMEMSIZE=4
HOST=`hostname`
CHECKHUGEPAGES=0

if [ "${CVU_TEST_ENV}" = "true" ] &&  [ "X${CVU_TEST_REQ_MEM}" != "X" ] && [ "X${CVU_TEST_NR_HP}" != "X" ]
then
     REQMEMSIZE=${CVU_TEST_REQ_MEM}  
     HUGEPAGEPATH=${CVU_TEST_NR_HP}
fi
 
# Gets the number of huge pages.
# If /proc/sys/vm/nr_hugepages file does not exist, hugepages is not enabled.


# Gets available memory
# It is suggested to enable Huge pages if Available Memory is >=4GB
getAvailMem()
{
PHYSMEM=`$SCAT /proc/meminfo | $SGREP MemTotal | $SAWK '{print $2}'`
ret=$?
if [ $ret -eq 0 ]
then
    #Since the decision to check for enabled hugepages only depends on whether the system has 4GB or more 
    #Physical memory unit is kB. Required memory is calculated in kB (4 GB = 4 * 1048576 kB)
    REQMEM=`expr $REQMEMSIZE \* 1048576`
else
    #Command Failure - Failed to get physical memory
    ERRCODE=4
    frameResult
    echo $RESULT
    exit
fi
if [ $PHYSMEM -ge $REQMEM ]    
then
    CHECKHUGEPAGES=1
    return
fi
return
}

frameResult()
{
  case $ERRCODE in
       0) RESULT="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Huge Pages feature is enabled on node $HOST</TRACE>"
          ;;
       1) RESULT="<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Huge Pages feature is not enabled on $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0021</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       2) RESULT="<RESULT>WARN</RESULT><COLLECTED><FACILITY>Prve</FACILITY><ID>10026</ID></COLLECTED><EXPECTED>true</EXPECTED><TRACE>Huge Pages feature is not supported on $HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0023</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       3) RESULT="<RESULT>WARN</RESULT><COLLECTED><FACILITY>Prve</FACILITY><ID>0070</ID></COLLECTED><EXPECTED><FACILITY>Prve</FACILITY><ID>0071</ID></EXPECTED><EXEC_ERROR>Transparent huge pages were found enabled always on the system</EXEC_ERROR><TRACE>Transparent huge pages enabled on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0024</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
       4) RESULT="<RESULT>WARN</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><EXEC_ERROR>Error while getting physical memory of the system</EXEC_ERROR><TRACE>Unable to get the physical memory of the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0022</ID><MSG_DATA><DATA>$HOST</DATA></MSG_DATA></NLS_MSG>"
          ;;
  esac
  return
}

#This function checks if hugepages are supported and enabled if supported
# The ERRCODE is set to following value indicating the status
# 0 enabled
# 1 not enabled
# 2 not supported
# 3 transparent hugepages are always enabled
checkHugePagesSupportedAndEnabled()
{
CHECKHUGEPAGES=`$SGREP Hugepage /proc/meminfo`
ret=$?
if [ $ret -eq 0 ]
then
    #Huge pages feature is supported on this system, lets check if it is enabled.
    if [ -f $HUGEPAGEPATH ]
    then
        #Huge pages feature is enabled, lets check if transparent hugepages are enabled
        if [ -f $TRANSPARENTHUGEPAGEPATH ]
        then
            CHECKHUGEPAGES=`$SGREP \[always\] $TRANSPARENTHUGEPAGEPATH`
            ret=$?
            if [ $ret -eq 0 ]
            then
                #Transparent huge pages are enabled, issue warning
                ERRCODE=3
            else
                #Success case
                ERRCODE=0
            fi
        else
            ERRCODE=0
        fi
    else
        ERRCODE=1
    fi
else
    ERRCODE=2
fi

}

# Note: This function does calculation for all shared memory
# segments available when the script is run, no matter it
# is an Oracle RDBMS shared memory segment or not.
getFixupData()
{
  # Check for the kernel version
  KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`
  # Find out the HugePage size
  HPG_SZ=`grep Hugepagesize /proc/meminfo | awk {'print $2'}`

  RETURN_CODE=0

  #check if we have a huge page size, if not then we should assume default of 2MB (i.e. 2048 kB) on linux
  if [ "$HPG_SZ" == "" ]; then
    HPG_SZ=2048
  fi

  # Start from 1 pages to be on the safe side and guarantee 1 free HugePage
  NUM_PG=1
  # Cumulative number of pages required to handle the running shared memory segments
  for SEG_BYTES in `ipcs -m | awk {'print $5'} | grep "[0-9][0-9]*"`
  do
     MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
     if [ $MIN_PG -gt 0 ]; then
        NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
     fi
  done

  # Display the results
  case $KERN in
     '2.4') HUGETLB_POOL=`echo "$NUM_PG*$HPG_SZ/1024" | bc -q`;
          echo "vm.hugetlb_pool = $HUGETLB_POOL" ;;
     '2.6') echo "vm.nr_hugepages = $NUM_PG" ;;
     *)    RETURN_CODE=1
          echo "Error Unrecognized kernel version $KERN for this fix-up. fix-up for hugepages settings is not supported for this kernel version. Exiting" ;;
  esac
}

#Main

if [ "X$1" = "X" ]
then
  getAvailMem
  if [ $CHECKHUGEPAGES -eq 1 ]
  then
      checkHugePagesSupportedAndEnabled
  else
      #Return Success
      ERRCODE=0
  fi
  frameResult
  echo $RESULT
elif [ "X$1" = "X-getfixupdata" ]; then
  getFixupData
fi

