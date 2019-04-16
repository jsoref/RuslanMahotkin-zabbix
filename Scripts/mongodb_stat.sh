#!/bin/sh
# Sending MongoDB server statistics to Zabbix server

MongoAPI(){
# Request for MongoDB API

 # Mongo options:
 # --quiet 'silent' shell output;
 # --eval computed javascript expression
 RespStr=$(/usr/bin/mongo --quiet --eval "print(JSON.stringify($1))" $2 | /etc/zabbix/JSON.sh -l 2>/dev/null)
 # No statistics available - returning service status - 'does not work'
 [ $? != 0 ] && echo 0 && exit 1
}


# DB list
MongoAPI 'db.getMongo().getDBs()'
DBStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/^databases..+.name$/ && $2!~/^local$/ {
 print $2
}')


# There are no parameters in the command line - sending data
if [ -z $1 ]; then
 # Server statistics
 MongoAPI 'db.serverStatus({cursors: 0, locks:0, wiredTiger: 0})'
 # Filtering, formatting statistics data
 OutStr=$((cat <<EOF
$RespStr
EOF
) | awk -F\\t '$1~/^(metrics.(cursor.(open.total|timedOut)|document.(deleted|inserted|returned|updated))|connections.(current|available)|globalLock.(currentQueue.(readers|total|writers)|activeClients.(total|readers|writers)|totalTime)|extra_info.(heap_usage_bytes|page_faults)|mem.(resident|virtual|mapped)|uptime|network.(bytes(In|Out)|numRequests)|opcounters.(command|delete|getmore|insert|query|update))(.floatApprox|.\$numberLong)?$/ {
  sub(".floatApprox", "", $1)
  sub(".\\$numberLong", "", $1)
  print "- mongodb." $1, int($2)
 }')

 # Field separator in the input line - for line-by-line processing
 IFS=$'\n'
 # Processing the database list
 for db in $DBStr; do
  # DB statistics
  MongoAPI 'db.stats()' $db
  # Formatting database statistics data in the output line
  for par in $RespStr; do
    OutStr="$OutStr
- mongodb.${par%%	*}[$db] ${par#*	}"
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

# DB detection
elif [ "$1" = 'db' ]; then
 # Separator for JSON list of names
 es=''
 # Processing the database list
 for db in $DBStr; do
  # JSON formatting of the database name in the output string
  OutStr="$OutStr$es{\"{#DBNAME}\":\"${db#*	}\"}"
  es=","
 done
 # Listing database in JSON format
 echo -e "{\"data\":[$OutStr]}"
fi
