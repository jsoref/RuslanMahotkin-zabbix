#!/bin/bash
# Sending Nginx server statistics to Zabbix server

# Getting the statistics line. Curl options:
# --max-time Maximum operation time in seconds;
# --no-keepalive disabling keepalive messages on a TCP connection;
# --silent disable load indicators and error messages;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`/ns")
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit 1

# Filtering, formatting and sending statistics data to Zabbix server
(cat <<EOF
$RespStr
EOF
) | awk '/^Active connections/ {active = int($NF)}
 /^ *[0-9]+ *[0-9]+ *[0-9]+/ {accepts = int($1); handled = int($2); requests = int($3)}
 /^Reading:/ {reading = int($2); writing = int($4); waiting = int($NF)}
 END {
  print "- nginx.active", active;
  print "- nginx.accepts", accepts;
  print "- nginx.handled", handled;
  print "- nginx.requests", requests;
  print "- nginx.reading", reading;
  print "- nginx.writing", writing;
  print "- nginx.waiting", waiting;
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
