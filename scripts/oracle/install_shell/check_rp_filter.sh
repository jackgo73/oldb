#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_rp_filter.sh /main/3 2014/03/07 03:01:50 ptare Exp $
#
# check_rp_filter.sh
#
# Copyright (c) 2011, 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      check_rp_filter.sh - check the reverse path filter setting for cluster private interconnect classified NICs 
#
#    DESCRIPTION
#      check the reverse path filter "rp_filter" parameter for NICS selected for private interconnect 
#
#    NOTES
#      Currently this check only applies to OEL6 and further LINUX releases 
#
#    MODIFIED   (MM/DD/YY)
#    ptare       04/27/11 - check the reverse path filter rp_filter for NICS on
#                           LINUX
#    ptare       04/27/11 - Creation
#
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
SECHO="echo"
SGREP="grep"
SAWK="awk"
SSYSCTL="/sbin/sysctl -q"
SEPARATOR=","
_HOST=`/bin/hostname`
HAS_WILDCARD="FALSE"

# Set default exit status to indicate failure.
existstatus=3
badNicList=""
expected="0|2"

#method to get the value of rp_flter kernel parameter for given interface or "all"
getRPFilterValue ()
{
  command="$SSYSCTL net.ipv4.conf.$1.rp_filter 2>/dev/null" #redirect the standard error to /dev/null 
  
  output=$(/bin/sh -c "$command")
  ret=$?

  if [ $ret -ne 0 ]; then
    val=-999 #assumed value if not present, to denote the absence
  else
    command="$SECHO $output | $SAWK '{print \$3}'"
    val=$(/bin/sh -c "$command")
    ret=$?
    if [ $ret -ne 0 ]; then
      val=-999 #assumed value if not present, to denote the absence
    fi
  fi

  return $ret;
}   

#method to check if passed input follows wild card pattern
checkWildCards()
{
  input=$1
  if [[ $input == *\** ]] ||
     [[ $input == *\.* ]] ||
     [[ $input == *\^* ]] ||
     [[ $input == *\$* ]] ||
     [[ $input == *\[* ]] ||
     [[ $input == *\]* ]] ||
     [[ $input == *\(* ]] ||
     [[ $input == *\)* ]] ||
     [[ $input == *\{* ]] ||
     [[ $input == *\}* ]];then
    HAS_WILDCARD="TRUE"
  else
    HAS_WILDCARD="FALSE"
  fi
}


#method to resolve the interface names by given subnet
processWildCardInterfaces()
{
  PVT_SUBNET="SUBNET,$1"
  pattern="<ADOPTER>"
  nicNameWithWildCards=$2

  #Get the network information on this node using exectask 
  currentDir=$(dirname $0)
  output=`$currentDir/exectask -getifinfo`
  #align the output of exectask to be lines starting with <ADOPTER> as this is what we are looking for
  output=`$SECHO $output | sed 's/<ADOPTER>/\n&/g'`
  array=""
  #Form only lines starting with <ADOPTER>
  for line in $output
  do
    if [[ $line == $pattern* ]]
    then
     array=$array$'\n'$line
    else
     array=$array$line
    fi
  done

  #Now for all the entries starting with <ADOPTER> search for the PVT_SUBNET matching entry
  for line in $array
  do
    if [[ $line == $pattern* ]]
    then
     if [[ $line == *$PVT_SUBNET* ]]
     then
       line=`$SECHO $line | sed 's/</\n/g'`
       for entry in $line
       do
         if [[ $entry == *NAME\,* ]]
         then
           ifname=`$SECHO $entry | sed 's/>/\n/g' |  $SAWK -F"," '{print $2}'`

           #check if we have a logical alias or VLAN form of interface name
           #extract the physical interface name from such entries if any
           if [[ $ifname == *\.* ]]
           then
             ifname=`$SECHO $ifname  | $SAWK -F"." '{print $1}'`
           elif [[ $ifname == *\-* ]]
           then
             ifname=`$SECHO $ifname  | $SAWK -F"-" '{print $1}'`
           fi

           #perform regular expression match of the interface name
           if [[ $ifname =~ $nicNameWithWildCards ]]
           then
             addInterfaceToList $ifname
           fi
         fi
       done
     fi
   fi
  done
}

#Add interface to the list
addInterfaceToList()
{
  interfaceName=$1
  if [ "$interfaceName" != "" ]
  then
    NUMBER_OF_PVT_NICS=`expr $NUMBER_OF_PVT_NICS + 1`
    if [ "$PVT_NIC_ARRAY" == "" ]
    then
      PVT_NIC_ARRAY=$interfaceName
    else
      PVT_NIC_ARRAY=$PVT_NIC_ARRAY$'\n'$interfaceName
    fi
  fi
}

#method to retrieve the network interface list
getNetInterfaceList()
{
  # the interface list is passed in the form "SUBNET/INTERFACE,SUBNET/INTERFACE", We filter this input to retrieve the interface names
  pvtNetworkList=$1
  subnetWithIfList=`$SECHO $pvtNetworkList | sed 's/,/ /g'`
  for subnetwork in $subnetWithIfList
  do
    subnet=`$SECHO $subnetwork | sed 's/>/\n/g' |  $SAWK -F"/" '{print $1}'`
    interface=`$SECHO $subnetwork | sed 's/>/\n/g' |  $SAWK -F"/" '{print $2}'`
    #check if the interface follows wildcard pattern
    checkWildCards "$interface"
    #if interface name is wildcard pattern then resolve it by subnet
    if [ "$HAS_WILDCARD" == "TRUE" ]
    then
      processWildCardInterfaces $subnet "$interface"
    else
      addInterfaceToList $interface
    fi
  done

  if [ $NUMBER_OF_PVT_NICS -eq 0 ]
  then
    result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while retrieving information about PRIVATE Interconnect list</EXEC_ERROR><TRACE>Unable to get the private interconnect list</TRACE><NLS_MSG><FACILITY>Prvg</FACILITY><ID>1512</ID><MSG_DATA></MSG_DATA></NLS_MSG>"
    existstatus=$ret
    report_and_exit
  fi
}

#method to add interface into the bad network interface list
addNICtoBadNicList()
{
  nicToAdd=$1
  if [ "X$badNicList" = "X" ]; then
    badNicList=$nicToAdd
  else
    badNicList=$badNicList$SEPARATOR$nicToAdd
  fi
}

# we need to retrieve the network interface list depending on the stage we are in
getNetInterfaceList $1

if [ $NUMBER_OF_PVT_NICS -lt 2 ]
then
  #If there is only one private interface then we need not check the param value and hence declare success
  result="<RESULT>SUCC</RESULT><COLLECTED>0</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Reverse path filter parameter rp_filter is correctly configured on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0452</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=0
  $SECHO $result
  exit $existstatus
fi

#first check if the setting for all interfaces is done for MAX value, if yes then we can report success
#now check if the consildated value for all NICS is set correctly
name="all"
getRPFilterValue $name 
allVal=$val

if [ $allVal -eq 2 ]; then
  #the consolidated value of rp_filter is set to MAX i.e. 2 for "all" the interfaces which is SUCCESS
  result="<RESULT>SUCC</RESULT><COLLECTED>$allVal</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Reverse path filter parameter rp_filter is correctly configured on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0452</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=0
  $SECHO $result
  exit $existstatus
elif [ $allVal -eq -999 ] || [ $allVal -eq 0 ] || [ $allVal -eq 1 ]; then
  if [ $allVal -eq -999 ]; then
    # the "all" for all the interfaces is not set,
    # which means each of the individual interface now must have value of either 0 or 2
    for nicname in $PVT_NIC_ARRAY
    do
      getRPFilterValue $nicname
      ret=$?
      # make sure the command ran successfully and returned the rp_filter value for this interface
      if [ $ret -ne 0 ]; then
        # this means the value is either not set or could not be read so add this interface to bad NIC list
        addNICtoBadNicList $nicname
      else
        if [ $val -ne 0 ] && [ $val -ne 2 ]; then
          # this means the interface has rp_filter value set to something incorrect,
          # lets add this interface to bad interface list
          addNICtoBadNicList $nicname
        fi
      fi
    done
  elif [ $allVal -eq 0 ]; then
    # the consolidated value set to "all" for all the interfaces is "0",
    # which means each of the individual interface now must have value of either 0 or 2
    for nicname in $PVT_NIC_ARRAY
    do
      getRPFilterValue $nicname
      # we cannot check for return value here because it is possible that the rp_filter parameter
      # is not set for an interface in cases when the value for "all" is set, 
      # consider the value of "all" for this interface in such cases
      if [ $val -eq -999 ]; then
        val=$allVal
      fi

      if [ $val -ne 0 ] && [ $val -ne 2 ]; then
        # this means the interface has rp_filter value set to something incorrect,
        # lets add this interface to bad interface list
        addNICtoBadNicList $nicname
      fi
    done
  else
    # the consolidated value set to "all" for all the interfaces is "1",
    # which means each of the individual interface now must have rp_filter set to value 2
    for nicname in $PVT_NIC_ARRAY
    do
      getRPFilterValue $nicname
      # we cannot check for return value here because it is possible that the rp_filter parameter
      # is not set for an interface in some cases when the value for "all" is set
      # consider the value of all for this interface
      if [ $val -eq -999 ]; then
        val=$allVal
      fi

      # the val must be 2 
      if [ $val -ne 2 ]; then
        # this means the interface has rp_filter value set to something incorrect,
        # lets add this interface to bad interface list
        addNICtoBadNicList $nicname
      fi
    done
  fi
else
  # the value set to "all" is neither 0,1 or 2 and hence it is also an error condition
  result="<RESULT>VFAIL</RESULT><COLLECTED>$allVal</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Reverse path filter parameter rp_filter is not correctly configured for $name interfaces on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0453</ID><MSG_DATA><DATA>$name</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=2
  $SECHO $result
  exit $existstatus
fi

if [ "X$badNicList" = "X" ]; then
  #This means all the private interconnect interfaces are having rp_filter parameter set correctly
  result="<RESULT>SUCC</RESULT><COLLECTED>$expected</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Reverse path filter parameter rp_filter is correctly configured on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0452</ID><MSG_DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=0
  $SECHO $result
  exit $existstatus
else
  result="<RESULT>VFAIL</RESULT><COLLECTED>1</COLLECTED><EXPECTED>$expected</EXPECTED><TRACE>Reverse path filter parameter rp_filter is not correctly configured for interfaces ($badNicList) on node $_HOST</TRACE><NLS_MSG><FACILITY>Prve</FACILITY><ID>0453</ID><MSG_DATA><DATA>$badNicList</DATA><DATA>$_HOST</DATA></MSG_DATA></NLS_MSG>"
  existstatus=2
  $SECHO $result
  exit $existstatus
fi


