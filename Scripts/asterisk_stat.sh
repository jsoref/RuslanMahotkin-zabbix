#!/bin/sh
# Sending Asterisk server statistics to Zabbix server

# Array of pairs of lines Asterisk command - a string of an awk program for processing a string
# team response
aComAwk=(
 'core show uptime seconds' '/System uptime:/ { print "uptime", int($4) }'
 'core show threads' '/threads listed/ { print "threads", int($2) }'
 'voicemail show users' '/voicemail users configured/ { print "voicemail.users", int($2) } BEGIN { m = 0 } /^default/ { m += int($NF) } END { print "voicemail.messages", m }'
 'sip show channels' '/active SIP/ { print "sip.channels.active", int($2) }'
 'iax2 show channels' '/active IAX/ { print "iax2.channels.active", int($2) }'
 'sip show peers' '/sip peers/ { print "sip.peers", int($2); print "sip.peers.online", int($6) + int($11) }'
 'iax2 show peers' '/iax2 peers/ { print "iax2.peers", int($2) }'
 'core show channels' '/active channels/ { print "channels.active", int($2) } /active calls/ { print "calls.active", int($2) } /calls processed/ { print "calls.processed", int($2) }'
 'xmpp show connections' '/Number of clients:/ { print "xmpp.connections", int($NF) }'
 'sip show subscriptions' '/active SIP subscriptions/ { print "sip.subscriptions", int($2) }'
 'sip show registry' '/SIP registrations/ { print "sip.registrations", int($2) } BEGIN { r = 0 } /Registered/ { r += 1 } END { print "sip.registered", int(r) }'
 'iax2 show registry' '/IAX2 registrations/ { print "iax2.registrations", int($2) } BEGIN { r = 0 } /Registered/ { r += 1 } END { print "iax2.registered", int(r) }'
)

# Forming a line of Asterisk commands from strings of array commands
CommandStr=$(
 for(( i = 0; i < ${#aComAwk[@]}; i += 2 )); do
  echo -n "Action: command\r\nCommand: ${aComAwk[i]}\r\n\r\n"
 done
)

# Run Asterisk commands via AMI interface
ResStr=$(/bin/echo -e "Action: Login\r\nUsername: Monitoring_User\r\nSecret: Monitoring_password\r\nEvents: off\r\n\r\n${CommandStr}Action: Logoff\r\n\r\n" | /usr/bin/nc 127.0.0.1 5038 2>/dev/null)
# No statistics available - returning service status - 'does not work'
[ $? != 0 ] && echo 0 && exit 1

# Index of the string of awk programs in an array
iAwk=1
# Field separator in the input line - for line-by-line processing
IFS=$'\n'
# Output line
OutStr=$(
 # Line by line processing the results of command execution
 for rs in $ResStr; do
  # Position to start next line in result row
  let "pos+=${#rs}+1"
  # Command line output message
  if [ "${rs}" = "Message: Command output follows"$'\r' ]; then
   # Save the position of the start of the result substring in the result string
   begin=$pos
  # End string of substring of the result of the command execution
  elif [[ "${rs:0:7}" != 'Output:' && -n "$begin" ]]; then
   # Running an awk program on a substring of the result of the command execution
   (cat <<EOF
${ResStr:$begin:$pos-$begin}
EOF
   ) | awk "${aComAwk[iAwk]}"
   # Switching the index of an awk program line in an array to the next
   let "iAwk+=2"
   # Clear position of the start of the result substring in the result string
   begin=
  fi
 # Insert at the beginning of each line
 done | awk '{ print "- asterisk."$0 }'
)

# ID of the Asterisk process from the PID file
pid=$(/bin/cat /var/run/asterisk/asterisk.pid 2>/dev/null)
# PID-file is missing - returning service status - 'does not work'
[ -z "$pid" ] && echo 0 && exit 1
# Output line of CPU and memory usage by the Asterisk process
OutStr1=$((/bin/ps --no-headers --pid $pid --ppid $pid -o pcpu,rssize || echo 0 0) | awk '{ c+=$1; m+=$2 } END { print "- asterisk.pcpu", c; print "- asterisk.memory", m*1024 }')

# Sending output line to Zabbix server. Parameters for zabbix_sender:
# --config agent configuration file;
# --host hostname on Zabbix server;
# --input-file data file ('-' - standard input)
(cat<<EOF
$OutStr
$OutStr1
EOF
) | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
echo 1
exit 0
