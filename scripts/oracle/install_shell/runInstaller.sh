#!/bin/sh
CUR_DIR=$(pwd)
RUNINSTALLER_DIR=`dirname $0`
cd $RUNINSTALLER_DIR
./runInstaller $* 
cd $CUR_DIR
