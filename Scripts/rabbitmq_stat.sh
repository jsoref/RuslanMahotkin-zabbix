#!/bin/bash
# Sending RabbitMQ server statistics to Zabbix server

CurlAPI(){
# Request to PabbitMQ API

# Curl options:
 # --max-time Maximum operation time in seconds;
 # --no-keepalive disabling keepalive messages on a TCP connection;
 # --silent disable load indicators and error messages;
 # --ciphers list of used cipher suites;
 # --insecure disabling verification of the HTTPS server certificate;
 # - tlsv1.2 using TLSv1.2;
 # --user 'user: password' authentication on server
 RespStr=$(/usr/bin/curl --max-time 20 --no-keepalive --silent --ciphers ecdhe_rsa_aes_128_gcm_sha_256 --insecure --tlsv1.2 --user Monitoring_user:Monitoring_password "https://127.0.0.1:15672/api/$1" | /etc/zabbix/JSON.sh -l 2>/dev/null)
# No statistics available - returning service status - 'does not work'
 [ $? != 0 ] && echo 0 && exit 1
}


# Output line
OutStr=''
# Field separator in the input line - for line-by-line processing
IFS=$'\n'
# There are no parameters in the command line - sending data
if [ -z $1 ]; then
# General Statistics
 CurlAPI 'overview?columns=message_stats,queue_totals,object_totals'
# Formatting general statistics data in the output line
 for par in $RespStr; do
  OutStr="$OutStr- rabbitmq.${par/	/ }\n"
 done

# Sending output line to Zabbix server. Parameters for zabbix_sender:
 # --config agent configuration file;
 # --host hostname on Zabbix server;
 # --input-file data file ('-' - standard input)
 echo -en $OutStr
# Returning the status of the service - 'works'
 echo 1
 exit 0

# per queue data
elif [ "$1" = 'queue' ]; then
 qn="$2"
 CurlAPI "queues/%2f/$qn?columns=message_stats,memory,messages,messages_ready,messages_unacknowledged,consumers"
  for par in $RespStr; do
   OutStr="$OutStr- rabbitmq.$(echo $par|cut -f1)[$qn] $(echo $par|cut -f2)\n"
  done
 echo -en $OutStr
 echo 1
 exit 0
# Queue detection
elif [ "$1" = 'queues' ]; then
# Queue list
 CurlAPI 'queues?columns=name'
# Separator for JSON list of names
 es=''
# Processing the queue list
 for q in $RespStr; do
# JSON formatting queue name in output string
  OutStr="$OutStr$es{\"{#QUEUENAME}\":\"${q#*	}\"}"
  es=","
 done
# Listing queues in JSON format
 echo -e "{\"data\":[$OutStr]}"
fi
