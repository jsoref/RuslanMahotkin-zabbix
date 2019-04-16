# PostgreSQL server statistics sending to Zabbix server

# The full name of the executable file of the PostgreSQL client
$PsqlExec = 'E:\PostgreSQL\9.4.2-1.1C\bin\psql'


function PSql($SQLStr){
# Run requests by calling psql. Parameters: 1 - SQL query string

# Run requests:
 # quiet - no messages, just the result of the query;
 # field-separator = - field separator;
 # no-align - unaligned table mode;
 # tuples-only - only result strings
 $RespStr = & $PsqlExec --quiet --field-separator=" " --no-align --tuples-only --host=127.0.0.1 --username=zabbix --command="$SQLStr;" template1 2>&1
 # Run queries successfully - return result string
 if( $? ){ return $RespStr }
 # No statistics available - returning service status - 'does not work'
 Write-Host 0
 # Exit Script
 exit 1
}


# Getting the string of the database list
$DBStr = PSql "SELECT datname FROM pg_stat_database where datname not like 'template%'"

# There is a DB definition command line argument
if( $args[0] -and $args[0] -eq 'db' ){
 # String the database list string to JSON format
 $DBStr = $DBStr -split '`n' -join '"},{"{#DBNAME}":"'
 if( $DBStr ){ $DBStr = "{`"{#DBNAME}`":`"" + $DBStr + "`"}" }
 $DBStr = "{`"data`":[" + $DBStr + "]}"
 # Output JSON-list of DB
 Write-Host -NoNewLine $DBStr

# Sending data
}else{
 # SQL query string
 $SelectsStr = '';
 # Adding to the query string statistics on the database
 # Requests for field value from the pg_stat_database table for the database
 'numbackends', 'deadlocks', 'tup_returned', 'tup_fetched', 'tup_inserted', 'tup_updated',`
  'tup_deleted', 'temp_files', 'temp_bytes', 'blk_read_time', 'blk_write_time',`
  'xact_commit', 'xact_rollback' | Where { $SelectsStr += "select '- postgresql." + $_ +
  "['||datname||'] '||" + $_ + " from pg_stat_database where datname not like 'template%' union " }
 # Complex queries for DB
 $DBStr -split '`n' | Where { $SelectsStr += "select '- postgresql.size[" + $_ +
  "] '||pg_database_size('" + $_ + "') union select '- postgresql.cache[" + $_ +
  "] '||cast(blks_hit/(blks_read+blks_hit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union select '- postgresql.success[" + $_ +
  "] '||cast(xact_commit/(xact_rollback+xact_commit+0.000001)*100.0 as numeric(5,2)) from pg_stat_database where datname='" +
  $_ + "' union "
  }

 # Adding general statistics to the query string
 # Requests from the pg_stat_activity table quantity values: 'parameter' = 'filter'
 @{
  'active'   = "state='active'";
  'idle'     = "state='idle'";
  'idle_tx'  = "state='idle in transaction'";
  'server'   = '1=1';
  'waiting'  = "waiting='true'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql.connections." + $_.Key +
  " '||count(*) from pg_stat_activity where " + $_.Value + " union " }

 # Queries field value from pg_stat_activity table
 'buffers_alloc', 'buffers_backend', 'buffers_backend_fsync', 'buffers_checkpoint',`
  'buffers_clean', 'checkpoints_req', 'checkpoints_timed', 'maxwritten_clean' |
  Where { $SelectsStr += "select '- postgresql." + $_ + " '||" + $_ +
  " from pg_stat_bgwriter union " }

 # Requests for the number of slow queries from the pg_stat_activity table: 'parameter' = 'filter'
 @{
  'slow.dml'     = "~* '^(insert|update|delete)'";
  'slow.queries' = "ilike '%'";
  'slow.select'  = "ilike 'select%'";
 }.GetEnumerator() | Where { $SelectsStr += "select '- postgresql." + $_.Key +
  " '||count(*) from pg_stat_activity where state='active' and now()-query_start>'5 sec'::interval and query " +
  $_.Value + " union " }

 # Maximum number of connections
 $SelectsStr += "select '- postgresql.connections.max '||setting::int from pg_settings where name='max_connections'"

 # Execution of requests and sending the output string to the Zabbix server. Parameters for zabbix_sender:
 # --config agent configuration file;
 # --host hostname on Zabbix server;
 # --input-file data file ('-' - standard input)
 PSql $SelectsStr | c:\Scripts\zabbix_sender.exe --config "c:\Scripts\zabbix_agentd_win.conf" --host "DNS.server.name" --input-file - 2>&1 | Out-Null

 # Returning the status of the service - 'works'
 Write-Host 1
}
