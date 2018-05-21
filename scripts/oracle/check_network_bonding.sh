#!/bin/sh
#
# $Header: opsm/cvutl/pluggable/unix/check_network_bonding.sh /main/1 2014/03/07 03:01:50 ptare Exp $
#
# check_network_bonding.sh
#
# Copyright (c) 2014, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      check_network_bonding.sh - Check the network bonding type used for
#                 cluster interconnect interfaces and report accordingly.
#
#    DESCRIPTION
#     This script verifies if network bonding feature is enabled on the node.
#     If enabled then collect the network bonding information if any of the 
#     private interfaces participate in the bonding configuration.
#
#     status                 output value in collected tags
#     ------                 ------------
#     SUCC                   1>none - If network interface bonding feature is not used.
#                            2>none - if no privately classified interfaces participate in network bonding.
#
#     WARN                   Information of all bonds in which private interfaces participate. this output is 
#                            bondwise interface list of the bonds in which the private interfaces participate on this node.
#
#     VFAIL                  Private interface information was not available to perform the check
#     
#     EFAIL                  error message information is included to indicate the error occurred.
#
#    NOTES
#    typical output example:
#    <COLLECTED>0=eth1,1=eth2,2=eth7,3=eth6,4=eth3,5=eth11,6=eth13</COLLECTED>   
#
#    MODIFIED   (MM/DD/YY)
#    ptare       02/12/14 - Pluggable script for checking network bonding
#                           status on Linux
#    ptare       02/12/14 - Creation
#
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
SECHO="echo"
SGREP="grep"
SAWK="awk"
BOND_DIRECTORY="/proc/net/bonding"
BONDING_FEATURE_USED="FALSE" #Assume false to begin with
#following variable contains the bondwise private interface list on this node in comma separated format
PARTICIPATING_BOND_IF_LIST=""
BOND_MODE=-1
BOND_ENTRY_SEPARATOR=","
IF_ENTRY_SEPARATOR=" "
BOND_IF_PAIR_SEPARATOR="="
_HOST=`/bin/hostname`
NUMBER_OF_PVT_NICS=0
HAS_WILDCARD="FALSE"
    
# Set default exit status to indicate failure.
existstatus=3

#method to report the outcome and return with exit status
report_and_exit () 
{   
  $SECHO $result
  exit $existstatus
}

#method to retrieve the bond BOND_MODE for given bond name
#This method is mainly an utility method to return the mode number for given bond type string
getBondMode ()
{
  strMode=$1

  if [[ "$strMode" == *load\ balancing* ]]
  then
    BOND_MODE=0
  elif [[ "$strMode" == *active-backup* ]]
  then
    BOND_MODE=1
  elif [[ "$strMode" == *balance-xor* ]]
  then
    BOND_MODE=2
  elif [[ "$strMode" == *broadcast* ]]
  then
    BOND_MODE=3
  elif [[ "$strMode" == *802.3ad* ]]
  then
    BOND_MODE=4
  elif [[ "$strMode" == *balance-tlb* ]]
  then
    BOND_MODE=5
  elif [[ "$strMode" == *balance-alb* ]]
  then
    BOND_MODE=6
  else
    BOND_MODE=-1
  fi
}

#method to check the bonding status and its mode type
checkNICBondingStatus ()
{
  #First check whether the bonding feature is used at all.
  #if used then there must exist the bond file under BOND_DIRECTORY for each bond configuration
  if [ -d "$BOND_DIRECTORY" ]; then
    #The directory for bonding files exists, The bonding feature is used
    #Let us list all the bond files which define active bonding mode
    allbondfiles=`$SGREP -l "^[[:space:]]Bonding Mode:" $BOND_DIRECTORY/*`
    ret=$?
    if [ $ret -ne 0 ]; then
      #Seems like none of the files under BOND_DIRECTORY contain active bond definition
      #We can safely conclude bonding is not enabled yet and exit
      BONDING_FEATURE_USED="FALSE"
    else
      #Bonding mode is defined in one or more bonding files, now we shall ensure that none of the
      #privately classified interfaces participates in the bond
      BONDING_FEATURE_USED="TRUE"
      for filepath in $allbondfiles
      do
        #Get the interfaces participating in this bond mode configuration
        INTERFACE_LIST_FOR_BOND=`$SGREP "^[[:space:]]Slave Interface:" $filepath | $SAWK -F\: '{print \$2}'`
        ret=$?
        if [ $ret -eq 0 ]; then
          #Get the bond mode type name defined inside the bond file
          BOND_MODE_STR=`$SGREP "^[[:space:]]Bonding Mode:" $filepath | $SAWK -F\: '{print \$2}'`
          ret=$?
          if [ $ret -eq 0 ]; then
            #Now we shall compare all the interfaces configured for this bond and check if any of our privately
            #classified interfaces participate in this bond, if yes then we report failure for those interfaces
            BOND_IF_LIST=""
            #convert the bond type name to its integer mode value
            getBondMode "$BOND_MODE_STR"

            #Now Iterate the bond interface list
            for bondIF in $INTERFACE_LIST_FOR_BOND
            do
              for pvtNIC in $PVT_NIC_ARRAY
              do
                if [ $pvtNIC == $bondIF ]; then
                  #Gather the information about the bond as there exists a participating prviate NIC as member
                  if [ "$BOND_IF_LIST" == "" ]; then
                    BOND_IF_LIST=$pvtNIC
                  else
                    BOND_IF_LIST=$BOND_IF_LIST$IF_ENTRY_SEPARATOR$pvtNIC
                  fi
                fi
              done
            done
            #Check if we have participating interface list for this bond and collect it if it exists
            if [ "$BOND_IF_LIST" != "" ]; then
              if [ "$PARTICIPATING_BOND_IF_LIST" == "" ]; then
                PARTICIPATING_BOND_IF_LIST=$BOND_MODE$BOND_IF_PAIR_SEPARATOR$BOND_IF_LIST
              else
                PARTICIPATING_BOND_IF_LIST=$PARTICIPATING_BOND_IF_LIST$BOND_ENTRY_SEPARATOR$BOND_MODE$BOND_IF_PAIR_SEPARATOR$BOND_IF_LIST
              fi
            fi
          fi
        fi
      done
    fi
  fi
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
  nicNameWithWildCard=$2
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
           if [[ $ifname =~ $nicNameWithWildCard ]]
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

  if [ $NUMBER_OF_PVT_NICS -eq 0 ]; then
    result="<RESULT>EFAIL</RESULT><EXEC_ERROR>Error while retrieving information about PRIVATE Interconnect list</EXEC_ERROR><TRACE>Unable to get the private interconnect list</TRACE><NLS_MSG><FACILITY>Prvg</FACILITY><ID>1512</ID><MSG_DATA></MSG_DATA></NLS_MSG>"
    existstatus=$ret
    report_and_exit
  fi
}


# we need to retrieve the network interface list depending on the stage we are in
getNetInterfaceList $1

if [ $NUMBER_OF_PVT_NICS -gt 0 ]; then
  #first check if the network interfaces bonding feature is used on this node
  #if the NIC bonding is not used then we can return success from here itself

  checkNICBondingStatus

  if [ "$BONDING_FEATURE_USED" == "FALSE" ]; then
    result="<RESULT>SUCC</RESULT><COLLECTED></COLLECTED><EXPECTED></EXPECTED><TRACE>Network interface bonding is not used on node $_HOST</TRACE>"
  else
    if [ "$PARTICIPATING_BOND_IF_LIST" == "" ]; then
      result="<RESULT>SUCC</RESULT><COLLECTED></COLLECTED><EXPECTED></EXPECTED><TRACE>Network interface bonding used but private interfaces ($PVT_NIC_ARRAY) do not participate in bonding on node $_HOST</TRACE>"
    else
      result="<RESULT>WARN</RESULT><COLLECTED>$PARTICIPATING_BOND_IF_LIST</COLLECTED><EXPECTED></EXPECTED><TRACE>Network interface bonding used on node $_HOST</TRACE>"
    fi
    existstatus=0
  fi
else
  #If there is no private interface then we need not check the network interface bonding status and hence declare success
  result="<RESULT>SUCC</RESULT><COLLECTED></COLLECTED><EXPECTED></EXPECTED><TRACE>The list of private interfaces was not available, skipped the check on node $_HOST</TRACE>"
  existstatus=1
fi

report_and_exit
