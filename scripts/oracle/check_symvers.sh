#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/check_symvers.sh /main/1 2011/04/22 09:20:40 agorla Exp $
#
# check_symvers.sh
#
# Copyright (c) 2011, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      check_symvers.sh - check if /boot is mounted
#
#    DESCRIPTION
#      check if /boot is mounted by is examining the existance of
#      /boot/symvers<running-kernel-version>.gz
#
#    NOTES
#      
#
#    MODIFIED   (MM/DD/YY)
#    agorla      04/11/11 - bug#11849901 - check symvers
#    agorla      04/11/11 - Creation
#


UNAME=/bin/uname
HOSTNAME=/bin/hostname
kernel_rel=`${UNAME} -r`
symvers=/boot/symvers-${kernel_rel}.gz
host=`${HOSTNAME}`

pres="<RESULT>SUCC</RESULT><COLLECTED>true</COLLECTED><EXPECTED>true</EXPECTED><TRACE>symvers file ${symvers} was found on node ${host}</TRACE>"

fres="<RESULT>VFAIL</RESULT><COLLECTED>false</COLLECTED><EXPECTED>true</EXPECTED><TRACE>symvers file ${symvers} was not found on node ${host}</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>10073</ID><MSG_DATA><DATA>${host}</DATA></MSG_DATA></NLS_MSG>"

if [ -f ${symvers} ]
then
  echo ${pres}
  exit 0
else
  echo ${fres}
  exit 1
fi
