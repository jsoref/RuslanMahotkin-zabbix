#!/bin/bash
# Sending Php-fpm server statistics to Zabbix server

# Getting the statistics line. Curl options:
# --max-time Maximum operation time in seconds;
# --no-keepalive disabling keepalive messages on a TCP connection;
# --silent disable load indicators and error messages;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`/ps")
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit

# Filtering, formatting and sending statistics data to Zabbix server
(cat <<EOF
$RespStr
EOF
) | awk -F: '$1~/^(accepted conn|listen queue|max listen queue|listen queue len|(idle|active|total|max active) processes|max children reached|slow requests)$/ {
 gsub(" ", "_", $1);
 print "- php-fpm." $1, int($2)
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
