#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/common_include.sh /main/2 2011/01/12 18:13:46 nvira Exp $
#
# common_include.sh
#
# Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. 
#
#    NAME
#      common_include.sh - <one-line expansion of the name>
#
#    DESCRIPTION
#      <short description of component this file declares/defines>
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    nvira       08/25/10 - shell script for setting common variables
#    nvira       08/25/10 - Creation
#

PLATFORM=`/bin/uname`

case $PLATFORM in
  Linux)
      _HOST=`/bin/hostname`
  ;;
  SunOS | HP-UX | AIX)
      _HOST=`/usr/bin/hostname`
  ;;
  
esac

