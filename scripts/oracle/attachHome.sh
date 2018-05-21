#!/bin/sh
OHOME=%ORACLE_HOME%
OHOMENAME=%ORACLE_HOME_NAME%
CUR_DIR=`pwd`
cd $OHOME/oui/bin
./runInstaller -detachhome ORACLE_HOME=$OHOME ORACLE_HOME_NAME=$OHOMENAME $* > /dev/null 2>&1
./runInstaller -attachhome ORACLE_HOME=$OHOME ORACLE_HOME_NAME=$OHOMENAME $* 
cd $CUR_DIR
