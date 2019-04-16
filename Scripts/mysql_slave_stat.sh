#!/bin/bash
# Sending MySQL server replication statistics to Zabbix server

# Getting the statistics line. mysql options:
# --user MySQL connection user;
# --password MySQL user password;
# --execute statement execution and exit
RespStr=$(/usr/bin/mysql --user=Monitoring_user --password=Monitoring_password --execute "SHOW SLAVE STATUS\G" 2>/dev/null)
# No statistics available - returning service status - 'does not work'
[ $? != 0 -o ! "$RespStr" ] && echo 0 && exit 1

# Filtering, formatting and sending statistics data to Zabbix server
(cat <<EOF
$RespStr
EOF
) | awk -F':' '$1~/^ +(Slave_(IO|SQL)_Running|Seconds_Behind_Master)$/ {
 gsub(" ", "", $0);
 sub("Yes", 1, $2);
 sub("No", 0, $2);
 sub("NULL", 0, $2);
 print "- mysql.slave." $1, $2
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
