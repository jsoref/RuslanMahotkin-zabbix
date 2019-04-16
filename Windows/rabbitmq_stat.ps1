# Sending RabbitMQ server statistics to Zabbix server


function RabbitMQAPI($Query){
# Request to PabbitMQ API. Parameters: 1 - API request parameter string

 # Uri API object PabbitMQ
 $uri = New-Object System.Uri("https://127.0.0.1:15672/api/$Query");

 # Preventing conversion of '%2f' to '/' character
 # Initialize the Uri object
 $uri.PathAndQuery | Out-Null
 $flagsField = $uri.GetType().GetField("m_Flags", [Reflection.BindingFlags]::NonPublic -bor [Reflection.BindingFlags]::Instance)
 # remove flags Flags.PathNotCanonical and Flags.QueryNotCanonical
 $flagsField.SetValue($uri, [UInt64]([UInt64]$flagsField.GetValue($uri) -band (-bnot 0x30)))

 $RespStr = $wc.DownloadString($uri) | ConvertFrom-Json
 # Execute the query successfully - return the result string
 if( $? ){ return $RespStr }
 # No statistics available - returning service status - 'does not work'
 Write-Host 0
 # Exit Script
 exit 1
}


# Output encoding - console encoding
$OutputEncoding = [Console]::OutputEncoding
# Disable verification of server certificate
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# List of used protocols
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11
# Web client for retrieving data identifiable by URI resources
$wc = New-Object System.Net.WebClient
# Authentication data
$wc.Credentials = New-Object System.Net.NetworkCredential('Monitor_User', 'Monitor_Password')

# Getting the queue list string
$QueuesStr = RabbitMQAPI 'queues?columns=name'

# There is a queue definition command line argument
if( $args[0] -and $args[0] -eq 'queues' ){
 # String the queue list string in JSON format
 $QueuesStr = $QueuesStr.name -split '`n' -join '"},{"{#QUEUENAME}":"'
 if( $QueuesStr ){ $QueuesStr = "{`"{#QUEUENAME}`":`"" + $QueuesStr + "`"}" }
 $QueuesStr = "{`"data`":[" + $QueuesStr + "]}"
 # Display JSON queue list
 Write-Host -NoNewLine $QueuesStr

# Sending data
}else{
 # Output line
 $OutStr = ''
 # General Statistics
 $Overview = RabbitMQAPI 'overview?columns=message_stats,queue_totals,object_totals'
 # Processing of required parameters of general statistics
 foreach($ParName in 'message_stats.ack_details.rate', 'message_stats.ack',
  'message_stats.deliver_get_details.rate', 'message_stats.deliver_get',
  'message_stats.get_details.rate', 'message_stats.get',
  'message_stats.publish_details.rate', 'message_stats.publish',
  'object_totals.channels', 'object_totals.connections',
  'object_totals.consumers', 'object_totals.exchanges', 'object_totals.queues',
  'queue_totals.messages', 'queue_totals.messages_ready',
  'queue_totals.messages_unacknowledged'){
  # Parameter value - initially root variable
  $ParValue = $Overview
  # Getting the value of the parameter
  foreach($i in $ParName.Split('.')){ $ParValue = $ParValue.$i }
  # Parameter not defined - initialization with zero value
  if($ParValue -eq $null){ $ParValue = 0 }
  # Displays the name and value of the parameter in the format zabbix_sender
  $OutStr += '- rabbitmq.' + $ParName + ' ' + $ParValue + "`n"
 }

 # Processing the queue list
 if($QueuesStr){
  foreach($Queue in $QueuesStr.name.Split('`n')){
   # Queue statistics query string
   $QueueQueryStr = 'queues/%2f/' + $Queue + '?columns=message_stats,memory,messages,messages_ready,messages_unacknowledged,consumers'
   # Queue statistics
   $QueueStat = RabbitMQAPI "$QueueQueryStr"
   # Processing required queue statistics settings
   foreach($ParName in 'consumers', 'memory', 'messages', 'messages_unacknowledged', 'messages_ready'){
    # Parameter value
    $ParValue = $QueueStat.$ParName
    # Parameter not defined - initialization with zero value
    if($ParValue -eq $null){ $ParValue = 0 }
    # Displays the name and value of the parameter in the format zabbix_sender
    $OutStr += '- rabbitmq.' + $ParName + '[' + $Queue + '] ' + $ParValue + "`n"
   }
  }
 }

 # Delete the last line break.
 # Sending output line to Zabbix server. Parameters for zabbix_sender:
 # --config agent configuration file;
 # --host hostname on Zabbix server;
 # --input-file data file ('-' - standard input)
 $OutStr.TrimEnd("`n") | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.server.name" --input-file - 2>&1 | Out-Null

 # Returning the status of the service - 'works'
 Write-Host 1
}
