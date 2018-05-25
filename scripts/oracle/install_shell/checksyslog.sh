#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/checksyslog.sh /main/1 2012/09/21 
#
# checksyslog.sh
#
# Copyright (c) 2009, 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      checksyslog.sh - Check kernel message logging on all platforms.
#
#    DESCRIPTION
#      This script will check the kernel message logging set in the 
#      /etc/syslog.conf file. If the '-' is specified before the log 
#      file then the logging will not wait for the 'fsync' (i.e. file
#      system write) to complete before returning to the client. 
#
#    NOTES
#      To remove the 'fsync' disk write add the '-' character in front
#      of the log file names specified in '/etc/syslog.conf'. The 
#      easiest way to do this is to execute the following command:
#
#      cat /etc/syslog.conf | sed 's/[\t ]\/var\/log/  \-\/var\/log/'
#
#      Then put the output of the above command into a new version of 
#      /etc/syslog.conf.
#
#    MODIFIED   (MM/DD/YY)
#    kfgriffi    10/08/13 - Fix bug 17572835
#    kfgriffi    09/21/12 - Creation
#

SGREP="/bin/grep"
SAWK="/bin/awk"
host=`/bin/hostname`
SYSLOGCONFIG="/etc/syslog.conf"
PLATFORM=`/bin/uname`

case $PLATFORM in
  HP-UX)
    SYSLOGCONFIG="/opt/ssh/etc/syslog.conf"
  ;;
  SunOS)
    SAWK="/usr/xpg4/bin/awk"
  ;;
esac

# Set default exit message to indicate failure in obtaining sys logging 
result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while getting syslog.conf information on the system</EXEC_ERROR><TRACE>Unable to read the '/etc/syslog.conf' information on the system: $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0053</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"

# Does the file exist on the system?
if [ ! -f $SYSLOGCONFIG ]
then
  # Set exit message to indicate an error finding syslog.conf file 
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error syslog.conf not found on the system</EXEC_ERROR><TRACE>Unable to find the '/etc/syslog.conf' information on the system: $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0054</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"

  echo $result
  exit $exitstatus
fi

# Does the user have read access to the file on the system?
read_output=`cat $SYSLOGCONFIG > /dev/null 2>&1`

ret=$?

if [ $ret != 0 ]
then
  # Set exit message to indicate an error reading syslog.conf file 
  result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error cannot read '/etc/syslog.conf' on the system</EXEC_ERROR><TRACE>Unable to read the '/etc/syslog.conf' information on the system: $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0055</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"

  echo $result
  exit $exitstatus
fi

case $PLATFORM in
  HP-UX | AIX | SunOS)
      fsyncLogging=`$SGREP "\/var\/log" $SYSLOGCONFIG | $SGREP -v "\-\/var\/log"`

      if [ "X${fsyncLogging}X" = "XX" ]
      then
        result="<RESULT>SUCC</RESULT><TRACE>fsync disk writes disabled for system logging $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0051</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=0
      else
        result="<RESULT>WARN</RESULT><TRACE>Log file syncing (i.e. fsync) for disk writes is enabled on system $host($PLATFORM) which may cause 'Connection reset by peer' errors</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0052</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=2
      fi
      ;;
  Linux)
      fsyncLogging=`$SGREP "\/var\/log" $SYSLOGCONFIG | $SGREP -v "\-\/var\/log"`

      if [ "X${fsyncLogging}X" = "XX" ]
      then
        result="<RESULT>SUCC</RESULT><TRACE>fsync disk writes disabled for system logging $host($PLATFORM)</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0051</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=0
      else
        result="<RESULT>WARN</RESULT><TRACE>fsync disk writes enabled for system logging on $host($PLATFORM) which may cause 'Connection reset by peer' errors</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0052</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
        existstatus=2
      fi
      ;;
esac

echo $result
exit $exitstatus
