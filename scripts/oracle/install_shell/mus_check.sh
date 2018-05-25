#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/mus_check.sh /main/1 2012/04/18 11:37:51 agorla Exp $
#
# mus_check.sh
#
# Copyright (c) 2012, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      mus_check.sh - checks multi-user-server and multi-user services are online on solaris
#
#    DESCRIPTION
#      
#
#    NOTES
#      
#
#    MODIFIED   (MM/DD/YY)
#    agorla      04/10/12 - bug#12875709 - multi-user-server check
#    agorla      04/10/12 - Creation
#

SVCS=/bin/svcs
AWK=/usr/xpg4/bin/awk
HOSTNAME=/bin/hostname

mus_status=`$SVCS -H svc:/milestone/multi-user-server |$AWK '{print $1}'`
mus_result=true  #assume that multi-user-server is online

mu_status=`$SVCS -H svc:/milestone/multi-user |$AWK '{print $1}'`
mu_result=true  #assume that multi-user is online
host=`$HOSTNAME`


if [ $mus_status != online ]
then
  echo "<RESULT>VFAIL</RESULT><COLLECTED>$mus_status</COLLECTED><EXPECTED>online</EXPECTED><TRACE>multi-user-server is $mus_status on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10113</ID><MSG_DATA><DATA>$mus_status</DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
  mus_result=false
fi

if [ $mu_status != online ]
then
  echo "<RESULT>VFAIL</RESULT><COLLECTED>$mus_status</COLLECTED><EXPECTED>online</EXPECTED><TRACE>multi-user is $mu_status on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10114</ID><MSG_DATA><DATA>$mus_status</DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
  mu_result=false
fi

if [ $mus_result = true -a $mu_result = true ]
then
  echo "<RESULT>SUCC</RESULT><COLLECTED>$mus_status</COLLECTED><EXPECTED>online</EXPECTED><TRACE>services multi-user-server and multi-user are online on node $host</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10112</ID><MSG_DATA><DATA>$host</DATA></MSG_DATA></NLS_MSG>"
fi

exit 0
