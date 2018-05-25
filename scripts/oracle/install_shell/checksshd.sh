#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/checksshd.sh /main/5 2011/01/12 18:13:46 nvira Exp $
#
# checksshd.sh
#
# Copyright (c) 2009, 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      checksshd.sh - Check SSHD setting on all platforms.
#
#    DESCRIPTION
#      This script will check Secure SHell Daemon settings that are
#      enabled on the platform that is executing this script.
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    kfgriffi    06/01/10 - Fix bug 9764799
#    kfgriffi    03/29/10 - Creation
#

SGREP="/bin/grep"
SAWK="/bin/awk"
host=`/bin/hostname`
SSHCONFIG="/etc/ssh/sshd_config"
SSHTIMEOUT="LoginGraceTime"
PLATFORM=`/bin/uname`

case $PLATFORM in
  HP-UX)
    SSHCONFIG="/opt/ssh/etc/sshd_config"
  ;;
  SunOS)
    SAWK="/usr/xpg4/bin/awk"
  ;;
esac

# Set default exit message to indicate failure in obtaining sshd timeout
# value.
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while getting SSHD timeout information on the system</EXEC_ERROR><TRACE>Unable to get the SSHD timeout information on the system: $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0039</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"

case $PLATFORM in
  HP-UX | AIX | SunOS)
      $SGREP $SSHTIMEOUT $SSHCONFIG > /dev/null 2>&1

      RET=$?

      if [ $RET -eq 0 ];
      then

        TimeOutVal=`$SGREP $SSHTIMEOUT $SSHCONFIG | $SGREP -v "#LoginGraceTime" | $SAWK '{if ("#" !~ $1 ) print $2}'`

        if [ "X${TimeOutVal}X" = "X0X" ]
        then
          result="<RESULT>SUCC</RESULT><TRACE>SSHD LoginGraceTime value set to zero on $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0037</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=0
        else
          result="<RESULT>WARN</RESULT><TRACE>SSHD LoginGraceTime value NOT set to zero on $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0038</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=2
        fi
      fi
      ;;
  Linux)
      # Cannot read SSHD_CONFIG file on Linux because it is owned by root
      # and does not allow read access. However, to insure testing of the
      # code that may eventually run on Linux the setup scripts modify the 
      # sshd_config file to allow the tests to execute. This may need to 
      # change in the future so leave it seperate from the other platforms.
      $SGREP $SSHTIMEOUT $SSHCONFIG > /dev/null 2>&1

      RET=$?

      if [ $RET -eq 0 ];
      then

        TimeOutVal=`$SGREP $SSHTIMEOUT $SSHCONFIG | $SGREP -v "#LoginGraceTime" | $SAWK '{if ("#" !~ $1 ) print $2}'`

        if [ "X${TimeOutVal}X" = "X0X" ]
        then
          result="<RESULT>SUCC</RESULT><TRACE>SSHD LoginGraceTime value set to zero on $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0037</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=0
        else
          result="<RESULT>WARN</RESULT><TRACE>SSHD LoginGraceTime value NOT set to zero on $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0038</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
          existstatus=2
        fi
      fi
      ;;
esac

echo $result
exit $exitstatus
