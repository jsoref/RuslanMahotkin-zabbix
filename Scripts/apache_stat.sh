#!/bin/bash
# Sending Apache server statistics to Zabbix server

# Getting the statistics line. Curl options:
# --max-time Maximum operation time in seconds;
# --no-keepalive disabling keepalive messages on a TCP connection;
# --silent disable load indicators and error messages;
RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent "http://`/bin/hostname`//as?auto")
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit 1

# Filtering, formatting and sending statistics data to Zabbix server
(cat <<EOF
$RespStr
EOF
) | awk -F: '!/^Scoreboard/ {
  gsub(" ", "", $1)
  print "- apache." $1 $2
  } /^Scoreboard/ {
   par["WaitingForConnection"] = "_"
   par["StartingUp"] = "S"
   par["ReadingRequest"] = "R"
   par["SendingReply"] = "W"
   par["KeepAlive"] = "K"
   par["DNSLookup"] = "D"
   par["ClosingConnection"] = "C"
   par["Logging"] = "L"
   par["GracefullyFinishing"] = "G"
   par["IdleCleanupOfWorker"] = "I"
   par["OpenSlotWithNoCurrentProcess"] = "\\."
   for(p in par) print "- apache." p, gsub(par[p], "", $2)
}' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
