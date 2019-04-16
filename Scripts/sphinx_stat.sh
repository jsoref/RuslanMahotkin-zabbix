#!/bin/bash
# Sending Sphinx server statistics to Zabbix server

SphinxAPI(){
# Request to Sphinx API

# Mysql options:
# --host name / address of the connection;
# --port connection port;
# --skip-column-names no column names in the output;
# --execute command execution and exit, turn off --force and history
   RespStr=$(/usr/bin/mysql --host=127.0.0.1 --port=9306 --skip-column-names --execute="SHOW $1;" 2>/dev/null)
# No statistics available - returning service status - 'does not work'
 [ $? != 0 ] && echo 0 && exit 1
}


# Index list
SphinxAPI 'TABLES'
IndexStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$2~/^local$/ { print $1}')

# There are no parameters in the command line - sending data
if [ -z $1 ]; then
# Server statistics
 SphinxAPI 'STATUS'
# Formatting statistics data
 OutStr=$((cat <<EOF
$RespStr
EOF
 ) | awk -F\\t '{ print "- sphinx." $1, $2 }')

# Field separator in the input line - for line-by-line processing
 IFS=$'\n'
# Processing index list
 for ind in $IndexStr; do
# Index statistics
  SphinxAPI "INDEX $ind STATUS"
# Formatting index statistics data in the output line
  for par in $RespStr; do
    OutStr="$OutStr
- sphinx.${par%%	*}[$ind] ${par#*	}"
  done
 done

# Sending output line to Zabbix server. Parameters for zabbix_sender:
# --config agent configuration file;
# --host hostname on Zabbix server;
# --input-file data file ('-' - standard input)
  (cat <<EOF
$OutStr
EOF
 ) | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
 echo 1
 exit 0

# Index detection
elif [ "$1" = 'indexes' ]; then
# Separator for JSON list of names
 es=''
# Processing index list
 for ind in $IndexStr; do
# JSON formatting of the index name in the output string
  OutStr="$OutStr$es{\"{#INDEXNAME}\":\"${ind#*	}\"}"
  es=","
 done
# Listing queues in JSON format
 echo -e "{\"data\":[$OutStr]}"
fi
