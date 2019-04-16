#!/bin/sh
# Sending Oracle server statistics to Zabbix server. Options:
# 1 - DB SID or 'tablespaces' for detecting table spaces

ExecSql(){
# Execute sql query. Parameters: 1 - query string

 ResStr=$(sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
set verify off echo off feedback off heading off pagesize 0 trimout on trimspool on termout off
conn monitoring_user / password_monitoring
column retvalue format a15
$1
EOF
)
# Mistake
 [ $? != 0 ] && exit 1
}


# Setting up an Oracle environment
. /etc/zabbix/oraenv

# There are no parameters in the command line - database detection
if [ -z $1 ]; then
# Getting the string of the list of database names
 DBStr=$(awk -F: '$1~/^[A-Za-z]+$/ { print $1 }' /etc/oratab 2>/dev/null)
# Mistake
 [ $? != 0 ] && exit 1
# JSON list delimiter
 es=''
# List processing
 for db in $DBStr; do
# JSON formatting of the name in the output string
  OutStr="$OutStr$es{\"{#DBNAME}\":\"$db\"}"
  es=","
 done
# List output in JSON format
 echo "{\"data\":[$OutStr]}"

# Tablespace detection
elif [ "$1" = 'tablespaces' ]; then
# Getting the string of the list of database names
 DBStr=$(awk -F: '$1~/^[A-Za-z]+$/ { print $1 }' /etc/oratab 2>/dev/null)
# Mistake
 [ $? != 0 ] && exit 1
# JSON list delimiter
 es=''
# List processing
 for db in $DBStr; do
# SID DB
  export ORACLE_SID=$db
# Getting a list of tablespace names
  ExecSql 'SELECT tablespace_name FROM dba_tablespaces;'
# List processing
  for ts in $ResStr; do
# JSON formatting of the name in the output string
   OutStr="$OutStr$es{\"{#DBNAME}\":\"$db\",\"{#TSNAME}\":\"$ts\"}"
   es=","
  done
 done
# List output in JSON format
 echo "{\"data\":[$OutStr]}"

# DB statistics
else
# SID DB
 db=$1
 export ORACLE_SID=$1

# Formats output numbers
 fmint='FM99999999999999990'
 fmfloat='FM99999990.9999'
# SQL substrings for obtaining statistics values
 ValueSysStatStr=" to_char(value, '$fmint') FROM v\$sysstat WHERE name = "
 TimeWaitedSystemEventStr=" to_char(time_waited, '$fmint') FROM v\$system_event se, v\$event_name en WHERE se.event(+) = en.name AND en.name = "
 ValueResourceLimitStr=" '$fmint') FROM v\$resource_limit WHERE resource_name = "
# SQL array of data element values
 aParSql=(
"'checkactive', to_char(case when inst_cnt > 0 then 1 else 0 end,'$fmint')
  FROM  (select count(*) inst_cnt FROM v\$instance
  WHERE status = 'OPEN' AND logins = 'ALLOWED' AND database_status = 'ACTIVE')"

"'rcachehit', to_char((1 - (phy.value - lob.value - dir.value) / ses.value)* 100, '$fmfloat')
  FROM  v\$sysstat ses, v\$sysstat lob, v\$sysstat dir, v\$sysstat phy
  WHERE ses.name = 'session logical reads'
        AND dir.name = 'physical reads direct'
        AND lob.name = 'physical reads direct (lob)'
        AND phy.name = 'physical reads'"

"'dsksortratio', to_char(d.value/(d.value + m.value)*100, '$fmfloat')
  FROM  v\$sysstat m, v\$sysstat d
  WHERE m.name = 'sorts (memory)' AND d.name = 'sorts (disk)'"

"'activeusercount', to_char(count(*)-1, '$fmint')
  FROM  v\$session
  WHERE username is not null AND status='ACTIVE'"

"'usercount', to_char(count(*)-1, '$fmint')
  FROM  v\$session
  WHERE username is not null"

"'dbsize', to_char(sum(NVL(a.bytes - NVL(f.bytes, 0), 0)), '$fmint')
  FROM  sys.dba_tablespaces d,
        (select tablespace_name, sum(bytes) bytes from dba_data_files group by tablespace_name) a,
        (select tablespace_name, sum(bytes) bytes from dba_free_space group by tablespace_name) f
  WHERE d.tablespace_name = a.tablespace_name(+)
        AND d.tablespace_name = f.tablespace_name(+)
        AND NOT (d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY')"

"'dbfilesize', to_char(sum(bytes), '$fmint')
  FROM  dba_data_files"

"'uptime', to_char((sysdate-startup_time)*86400, '$fmint')
  FROM  v\$instance"

"'hparsratio', to_char(h.value/t.value*100,'$fmfloat')
  FROM  v\$sysstat h, v\$sysstat t
  WHERE h.name = 'parse count (hard)' AND t.name = 'parse count (total)'"

"'lastarclog', to_char(max(SEQUENCE#), '$fmint')
  FROM  v\$log
  WHERE archived = 'YES'"

"'lastapplarclog', to_char(max(lh.SEQUENCE#), '$fmint')
  FROM  v\$loghist lh, v\$archived_log al
  WHERE lh.SEQUENCE# = al.SEQUENCE# AND applied='YES'"

"'processescurrent', to_char(current_utilization,$ValueResourceLimitStr'processes'"
"'sessionscurrent', to_char(current_utilization,$ValueResourceLimitStr'sessions'"
"'processeslimit', to_char(limit_value,$ValueResourceLimitStr'processes'"
"'sessionslimit', to_char(limit_value,$ValueResourceLimitStr'sessions'"

"'commits',$ValueSysStatStr'user commits'"
"'rollbacks',$ValueSysStatStr'user rollbacks'"
"'deadlocks',$ValueSysStatStr'enqueue deadlocks'"
"'redowrites',$ValueSysStatStr'redo writes'"
"'tblscans',$ValueSysStatStr'table scans (long tables)'"
"'tblrowsscans',$ValueSysStatStr'table scan rows gotten'"
"'indexffs',$ValueSysStatStr'index fast full scans (full)'"
"'netsent',$ValueSysStatStr'bytes sent via SQL*Net to client'"
"'netresv',$ValueSysStatStr'bytes received via SQL*Net from client'"
"'netroundtrips',$ValueSysStatStr'SQL*Net roundtrips to/from client'"
"'logonscurrent',$ValueSysStatStr'logons current'"

"'freebufwaits',$TimeWaitedSystemEventStr'free buffer waits'"
"'bufbusywaits',$TimeWaitedSystemEventStr'buffer busy waits'"
"'logswcompletion',$TimeWaitedSystemEventStr'log file switch completion'"
"'logfilesync',$TimeWaitedSystemEventStr'log file sync'"
"'logprllwrite',$TimeWaitedSystemEventStr'log file parallel write'"
"'enqueue',$TimeWaitedSystemEventStr'enqueue'"
"'dbseqread',$TimeWaitedSystemEventStr'db file sequential read'"
"'dbscattread',$TimeWaitedSystemEventStr'db file scattered read'"
"'dbsnglwrite',$TimeWaitedSystemEventStr'db file single write'"
"'dbprllwrite',$TimeWaitedSystemEventStr'db file parallel write'"
"'directread',$TimeWaitedSystemEventStr'direct path read'"
"'directwrite',$TimeWaitedSystemEventStr'direct path write'"
"'latchfree',$TimeWaitedSystemEventStr'latch free'"
 )

# Forming a string of queries for the values of data elements from an array
 SqlStr=''
 for p in "${aParSql[@]}"; do
  SqlStr="${SqlStr}SELECT ${p};
"
 done

# Receiving and adding to the output line the values of data elements
 OutStr=''
 ExecSql "$SqlStr"
# Field separator in the input line - for line-by-line processing
 IFS=$'\n'
 for par in $ResStr; do
# Validation of the value
  [ $par == ${par#* } ] || OutStr="$OutStr- oracle.${par%% *}[$db] ${par#* }\n"
 done

# Retrieving data on tablespaces
 ExecSql "SELECT df.tablespace_name || ' ' || totalspace || ' ' || nvl(freespace, 0)
  FROM
  (SELECT tablespace_name, SUM(bytes) totalspace
    FROM dba_data_files
    GROUP BY tablespace_name) df,
  (SELECT tablespace_name, SUM(Bytes) freespace
    FROM dba_free_space
    GROUP BY tablespace_name) fs
  WHERE df.tablespace_name = fs.tablespace_name (+);
  SELECT tf.tablespace_name || ' ' || totalspace || ' ' || (totalspace - used)
  FROM
  (SELECT tablespace_name, SUM(bytes) totalspace
    FROM dba_temp_files
    GROUP BY tablespace_name) tf,
  (SELECT tablespace_name, used_blocks*8192 used
    FROM v\$sort_segment) ss
  WHERE tf.tablespace_name = ss.tablespace_name;"

# Adding data on table spaces to the output string
 for par in $ResStr; do
# Name of tablespace
  ts=${par%% *}
# Allocation of full and free table space sizes
  par=${par#* }
  OutStr="$OutStr- oracle.tablespace.size[$db,$ts] ${par%% *}\n"
  OutStr="$OutStr- oracle.tablespace.free[$db,$ts] ${par#* }\n"
 done

# Sending output line to Zabbix server. Parameters for zabbix_sender:
 # --config agent configuration file;
 # --host hostname on Zabbix server;
 # --input-file data file ('-' - standard input)
 echo -en $OutStr | /usr/bin/zabbix_sender --config /etc/zabbix/zabbix_agentd.conf --host=`hostname` --input-file - >/dev/null 2>&1
# Returning the status of the service - 'works'
 echo 1
 exit 0
fi
