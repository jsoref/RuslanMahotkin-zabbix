#!/bin/bash
# Sending Redis server statistics to Zabbix server

# Getting the statistics line. Redis-cli options:
# -s socket is the full name of the socket file;
# info all command to get all the information and statistics
RespStr=$(/usr/bin/redis-cli -s /full/name/file/socket info all 2>/dev/null)
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit 1

# There are no parameters in the command line - sending data
if [ -z $1 ]; then
# Filtering, formatting and sending statistics data to Zabbix server
 (cat <<EOF
$RespStr
EOF
 ) | awk -F: '$1~/^(uptime_in_seconds|(blocked|connected)_clients|used_memory(_rss|_peak)?|total_(connections_received|commands_processed)|instantaneous_ops_per_sec|total_net_(input|output)_bytes|rejected_connections|(expired|evicted)_keys|keyspace_(hits|misses))$/ {
  print "- redis." $1, int($2)
 }
 $1~/^cmdstat_(get|setex|exists|command)$/ {
  split($2, C, ",|=")
  print "- redis." $1, int(C[2])
 }
 $1~/^db[0-9]+$/ {
  split($2, C, ",|=")
  for(i=1; i < 6; i+=2) print "- redis." C[i] "[" $1 "]", int(C[i+1])
 }' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
 echo 1
 exit 0

# DB detection
elif [ "$1" = 'db' ]; then
# Forming a list of databases in JSON format
 (cat <<EOF
$RespStr
EOF
 ) | awk -F: '$1~/^db[0-9]+$/ {
  OutStr=OutStr es "{\"{#DBNAME}\":\"" $1 "\"}"
  es=","
 }
 END { print "{\"data\":[" OutStr "]}" }'
fi
