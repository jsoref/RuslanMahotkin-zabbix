#!/bin/sh
# Sending Postfix server statistics to Zabbix server

# Getting the statistics line. Parameters logtail.sh:
# -l full log file name
# -o full offset file name
# Pflogsumm parameters:
# -h is the number of lines in the host report; 0 - not
# created;
# -u the number of lines of the top in the user report; 0 - not
# created;
# --mailq mailq command execution at the end of the report;
# --no_bounce_detail, --no_deferral_detail, --no_reject_detail
# hide detailed reports;
# --no_no_msg_size disable report on messages without data size;
# --no_smtpd_warnings disabling a report on SMTPD warnings;
# - smtpd_stats SMTPD Connection Statistics
RespStr=$(sudo /etc/zabbix/logtail.pl -l /var/log/maillog -o /tmp/postfix_stat.dat | /usr/sbin/pflogsumm -h 0 -u 0 --mailq --no_bounce_detail --no_deferral_detail --no_no_msg_size --no_reject_detail --no_smtpd_warnings --smtpd_stats 2>/dev/null)
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit

# Filtering, formatting and sending statistics data to Zabbix server
(cat <<EOF
$RespStr
EOF
) | awk '/^ +[0-9]+[kmg]? +(received|delivered|forwarded|deferred|bounced|rejected|reject warnings|held|discarded|bytes (received|delivered)|senders|recipients|(sending|recipient) hosts\/domains|connections)( +\([0-9]+%\))?$/ {
 if( $2 ~/^(reject|bytes)$/ ) $2 = $2"_"$3
 if( $2 ~/^(sending|recipient)$/ ) $2 = $2"_hosts"
 p = 0
 if( $1 ~/k$/ ) p = 1
 if( $1 ~/m$/ ) p = 2
 if( $1 ~/g$/ ) p = 3
 print "- postfix." $2, int($1) * 1024 ^ p
 }
 BEGIN { par["all"] = 0; par["active"] = 0; par["hold"] = 0; par["size"] = 0 }
 /^[0-9A-F]+[*!]? +[0-9]+/ {
  if( $1 ~/*$/ ) par["active"] += 1
  if( $1 ~/!$/ ) par["hold"] += 1
  par["all"] += 1
  par["size"] += int($2)
 }
 END { for(p in par) print "- postfix.queue." p, par[p] }
' | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
