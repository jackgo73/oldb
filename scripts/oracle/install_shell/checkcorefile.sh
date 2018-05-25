#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/checkcorefile.sh /main/5 2011/01/12 18:13:46 nvira Exp $
#
# checkcorefile.sh
#
# Copyright (c) 2009, 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checkcorefile.sh - Check core file setting on all platforms.
#
#    DESCRIPTION
#      This script will check to see if per-process core file dumping is
#      enabled on the platform that is executing this script.
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       09/29/10 - set expected and available values
#    kfgriffi    06/10/10 - Remove 'if' statement for HP-UX
#    kfgriffi    05/27/10 - Add expected value
#    kfgriffi    03/18/09 - Creation
#

PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin


SCAT="cat"
SGREP="grep"
COREADM="/usr/bin/coreadm"

# Get the core file value.
# The way core file information is collected is dependent on which platform
# is being looked at.
PLATFORM=`/bin/uname`

# Set default exit message to indicate failure in obtaining core file
# dump value.
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while getting Core File setting information on the system</EXEC_ERROR><TRACE>Unable to get the Core File setting information on the system</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0034</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
existstatus=3

case $PLATFORM in
  SunOS | HP-UX)
      host=`/usr/bin/hostname`
      coreFileEnabled=`$COREADM | $SGREP "per-process core dumps: enabled"`
      if [ "XCVUX${coreFileEnabled}" != "XCVUX" ]
      then
        result="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Core File Dump feature is enabled on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0032</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=0
      else
        result="<RESULT>WARN</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Core File Dump feature is NOT enabled on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0033</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=2
      fi
      ;;
  AIX)
      # Core files always enabled on AIX
        result="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Core File Dump feature is enabled on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0032</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=0
      ;;
  Linux)
      host=`/bin/hostname`
      if [ -f "/proc/sys/kernel/suid_dumpable" ]
      then
        corefilepath="/proc/sys/kernel/suid_dumpable"
      else 
        if [ -f "/proc/sys/fs/suid_dumpable" ]
        then
          corefilepath="/proc/sys/fs/suid_dumpable"
        else
          if [ -f "/proc/sys/kernel/core_setuid_ok" ]
          then 
            corefilepath="/proc/sys/kernel/core_setuid_ok"
          else
            corefilepath="UNKOWN"
          fi
        fi
      fi

      if [ -f $corefilepath ]
      then
        corefiles=`$SCAT $corefilepath`

        if [ $corefiles -eq 1 ]
        then 
          result="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Core File Dump feature is enabled on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0032</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=0
        else
          result="<RESULT>WARN</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>Core File Dump feature is NOT enabled on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0033</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=2
        fi   
      fi
      ;;
esac

echo $result
exit $existstatus
