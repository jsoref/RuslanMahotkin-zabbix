#!/bin/bash
# Sending disk I / O statistics to Zabbix server


# There are no parameters in the command line - sending data
if [ -z $1 ]; then
  # Getting the statistics line. Iostat options:
  # -d device usage statistics;
  # -k statistics in kilobytes per second;
  # -x extended statistics;
  # -y skip the first statistics (from the moment of loading);
  # 5 time in seconds between reports;
  # 1 number of reports
 RespStr=$(/usr/bin/iostat -dkxy 5 1 2>/dev/null)
 # No statistics available - returning service status - 'does not work'
 [ $? != 0 ] && echo 0 && exit 1

 # Filtering, formatting and sending statistics data to Zabbix server
 (cat <<EOF
$RespStr
EOF
 ) | awk 'BEGIN {split("disk rrqm_s wrqm_s r_s w_s rkB_s wkB_s avgrq-sz avgqu-sz await r_await w_await svctm util", aParNames)}
  $1 ~ /^[hsv]d[a-z]$/ {
  gsub(",", ".", $0);
  if(NF == 14)
   for(i = 2; i <= 14; i++) print "- iostat."aParNames[i]"["$1"]", $i
 }' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
 # Returning the status of the service - 'works'
 echo 1
 exit 0

# Disk detection
elif [ "$1" = 'disks' ]; then
 # Disk list string
 DiskStr=`/usr/bin/iostat -d | awk '$1 ~ /^[hsv]d[a-z]$/ {print $1}'`
 # Separator for JSON list of names
 es=''
 # Processing the list of disks
 for disk in $DiskStr; do
  # JSON formatting of the drive name in the output string
  OutStr="$OutStr$es{\"{#DISKNAME}\":\"$disk\"}"
  es=","
 done
 # List of disks in JSON format
 echo -e "{\"data\":[$OutStr]}"
fi
