#!/bin/bash    
    
export LANG=en_US.utf8 
# change me !   
export PGHOME=/opt/pgsql 
export LD_LIBRARY_PATH=$PGHOME/lib:/lib64:/usr/lib64:/usr/local/lib64:/lib:/usr/lib:/usr/local/lib:$LD_LIBRARY_PATH    
export DATE=`date +"%Y%m%d"`    
export PATH=$PGHOME/bin:$PATH:.    
# change me !
BASEDIR="/pgdata/digoal/1921/data04/pg93archdir"    
    
if [ ! -d $BASEDIR/$DATE ]; then    
  mkdir -p $BASEDIR/$DATE    
  if [ ! -d $BASEDIR/$DATE ]; then    
    echo "error mkdir -p $BASEDIR/$DATE"    
    exit 1    
  fi    
fi    
    
cp $1 $BASEDIR/$DATE/$2    
if [ $? -eq 0 ]; then    
  exit 0    
else    
  echo -e "cp $1 $BASEDIR/$DATE/$2 error"    
  exit 1    
fi    
    
echo -e "backup failed"    
exit 1    