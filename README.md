# zabbix
A set of scripts and templates for monitoring various services.

The basic principles of writing scripts:

- simplicity: a small amount of code;
- uniformity: the same approaches to receive. processing and sending statistics to the server;
- standard tools: use of the utilities running in the distribution kit and installed by default (mostly);
- data type trapper;
- data is obtained by a single request to the service;
- data is sent to the server in one package;
- collecting / sending all data and detection in one scenario.

Scripts do not collect all available data - filtering is performed or in
the script itself, or due to the absence of their description in the template by the Zabbix server.

Versions of services:

- Apache 2.2.15;
- Asterisk 16.1;
- Elasticsearch 1.7.1;
- Mongodb 4.0.6;
- MySQL 8.0.13;
- Nginx 1.14.2;
- Oracle 10g;
- PHP-FPM 7.3.1;
- RabbitMQ 3.6.6 (erlang 19.2);
- Redis 5.0.3;
- Sphinx 2.2.11.

General description of the script:

1. The script is called by the Zabbix server to get the value of the zabbix-agent Status variable described in the template.
2. The script receives, filters, processes, and sends to the zabbix_sender server all data at a time.

# Linux (CentOS 6.X)

Scenarios:

- written in bash;
- receive data by curl or a regular customer of the service;
- filter / process data using awk;
- send data to zabbix_sender;
- placed in the `/etc/zabbix` directory.

Installation Procedure:

- Installation of agent packages and data sending utility: zabbix, zabbix-agent,
 zabbix-sender.

- Start the agent at system startup and rights to the directory / configuration file:

  ```
  chmod 700 /etc/rc.d/init.d/zabbix-agent; chkconfig zabbix-agent on
  chmod 2750 /etc/zabbix; chgrp -R zabbix /etc/zabbix
  chmod 640 /etc/zabbix/zabbix_agentd.conf
  ```

- Resolution of ports in the firewall:

  ```
  # IP address of Zabbix server
  $ZabbServIP = 'X.X.X.X'
  # Agent
  /sbin/iptables -A INPUT -p tcp --dport 10050 -s $ZabbServIP -j ACCEPT
  /sbin/iptables -A OUTPUT -p tcp --sport 10050 -d $ZabbServIP -j ACCEPT
  # Server
  /sbin/iptables -A OUTPUT -p tcp --dport 10051 -d $ZabbServIP -j ACCEPT
  /sbin/iptables -A INPUT -p tcp --sport 10051 -s $ZabbServIP -j ACCEPT
  ```

- Agent settings in the `/etc/zabbix/zabbix_agentd.conf` file:

  ```
  SourceIP = IP.address.zabbix.agent
  Server = IP.address.zabbix.server
  ListenIP = IP.address.zabbix.agent
  ServerActive = IP.zabbix.server
  Timeout => 5
  ```

- Install the required scripts.

To handle JSON data in monitoring Elasticsearch, MongoDB and RabbitMQ
used corrected JSON.sh (http://github.com/dominictarr/JSON.sh).

## Apache, template mytemplate-apache-trap.xml

It is supposed that Apache works for nginx.

Script of sending Apache server statistics to Zabbix server

```
chmod 750 /etc/zabbix/apache_stat.sh
chgrp zabbix /etc/zabbix/apache_stat.sh
```

`/etc/nginx/nginx.conf` - add to the monitoring server (described in the nginx section)

```
  # Apache statistics
  location = /as {
   # Address of the proxy server
   proxy_pass http://127.0.0.1;
  }
```

In httpd.conf set parameters:

- `ServerName` - the hostname returned by hostname;
- `Allow from` - server IP address.

`/etc/https/conf/httpd.conf` - creating a monitoring server

```
# Status module
LoadModule status_module modules/mod_status.so
...
# Save extended information about each request
Extendedstatus on
...
# Monitoring ----------------------------------------------
<VirtualHost 127.0.0.1:80>
 # Server name
 ServerName DNS.server.name.
 # Turn off logging
 CustomLog /dev/null combined

 <Location /as>
  SetHandler server-status
  Order allow, deny
  Allow from IP.address
 </Location>
</Virtualhost>
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=apache_status,/etc/zabbix/apache_stat.sh
```

Restarting services

```
service nginx reload; service httpd restart; service zabbix-agent restart
```

## Asterisk, mytemplate-asterisk-trap.xml Template

Install **Netcat** utility - `nc` package (on **CentOS 7** - `nmap-ncat`).

In the AMI module configuration file and scripts in the substring

```
... Username: monitoring_service\r\nSecret: Monitoring_password\r\n...
```

set your values `Monitoring_user` and `Monitoring_password`.

`/etc/asterisk/manager.conf` - configure the AMI module and set the user

```
[general]
enabled = yes
bindaddr = 127.0.0.1
allowmultiplelogin = no
displayconnects = no
authtimeout = 5
authlimit = 3

[Monitoring_user]
secret=Monitoring_password
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
write = command,reporting
```

Restart AMI Module

```
asterisk -rx 'manager reload'
```

Scenario of sending Asterisk server statistics to Zabbix server

```
chmod 750 /etc/zabbix/asterisk_stat.sh
chgrp zabbix /etc/zabbix/asterisk_stat.sh
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=asterisk_status,/etc/zabbix/asterisk_stat.sh
```

Agent restart

```
service zabbix-agent restart
```

## Elasticsearch, mytemplate-elasticsearch-trap.xml template

Scenario of sending statistics of Elasticsearch server to Zabbix server

```
chmod 750 /etc/zabbix/{elasticsearch_stat.sh,JSON.sh}
chgrp zabbix /etc/zabbix/{elasticsearch_stat.sh,JSON.sh}
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=elasticsearch_status,/etc/zabbix/elasticsearch_stat.sh
```

Agent restart

```
service zabbix-agent restart
```

## IO - disk I/O, template mytemplate-io-trap.xml

Since the script makes a `iostat` call with a 5 second measurement, the parameter
`Timeout` in` zabbix_agentd.conf` must be greater than 5.

Install the package `sysstat` (version not lower than 9.0.4-27). Remove collection of cron statistics

```
rm -f /etc/cron.d/sysstat
```

Scenario of sending disk I/O statistics to Zabbix server

```
chmod 750 /etc/zabbix/io_stat.sh
chgrp zabbix /etc/zabbix/io_stat.sh
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=iostat_status,/etc/zabbix/io_stat.sh
UserParameter=iostat.discovery_disks,/etc/zabbix/io_stat.sh disks
```

Agent restart

```
service zabbix-agent restart
```

## MongoDB, template mytemplate-mongodb-trap.xml

Scenario of sending statistics of the MongoDB server to the Zabbix server

```
chmod 750 /etc/zabbix/{JSON.sh,mongodb_stat.sh}
chgrp zabbix /etc/zabbix/{JSON.sh,mongodb_stat.sh}
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=mongodb_status,/etc/zabbix/mongodb_stat.sh
UserParameter=mongodb.discovery_db,/etc/zabbix/mongodb_stat.sh db
```

Agent restart

```
service zabbix-agent restart
```

## MySQL template mytemplate-mysql-trap.xml

In the script in the substring

```
... --user = monitoring_user --password = Monitoring_password ...
```

set your values `Monitoring_user` and `Monitoring_password`.

Scenario of sending MySQL server statistics to Zabbix server

```
chmod 750 /etc/zabbix/mysql_stat.sh
chgrp zabbix /etc/zabbix/mysql_stat.sh
```

Mysql monitoring user

```
mysql -p
mysql> GRANT USAGE ON *.* TO 'Monitoring_User' @ 'localhost' IDENTIFIED BY 'Monitoring_password';
mysql> FLUSH PRIVILEGES;
mysql> \q
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=mysql_status,/etc/zabbix/mysql_stat.sh
```

Agent restart

```
service zabbix-agent restart
```

## MySQL replication, template mytemplate-mysql-slave-trap.xml

Scenario of sending MySQL server replication statistics to Zabbix server

```
chmod 750 /etc/zabbix/mysql_slave_stat.sh
chgrp zabbix /etc/zabbix/mysql_slave_stat.sh
```

Client Replication Privilege Mysql Monitoring User

```
mysql -p
mysql> GRANT REPLICATION CLIENT ON *.* TO 'Monitoring_User' @ 'localhost';
mysql> FLUSH PRIVILEGES;
mysql> \q
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=mysql_slave_status,/etc/zabbix/mysql_slave_stat.sh
```

Agent restart

```
service zabbix-agent restart
```

## Nginx, template mytemplate-nginx-trap.xml

Scenario of sending Nginx server statistics to Zabbix server

```
chmod 750 /etc/zabbix/nginx_stat.sh
chgrp zabbix /etc/zabbix/nginx_stat.sh
```

In `httpd.conf` set parameters:

- `server_name` - the hostname returned by hostname;
- `listen` and` allow` - server IP address.

`/etc/nginx/nginx.conf` - creating a monitoring server

```
 # Monitoring server -------------------------------------
 server {
  # Listening address: port (*:80 | *:8000)
  listen server.ip.addr.ess:80;
  # Virtual server name and aliases (_)
  server_name DNS.name.server;

  # Turn off logging
  access_log off;
  # Timeout of closing the keep-alive connection on the server side in seconds (75)
  keepalive_timeout 0;

  ### Server Access
  # Local
  allow server.ip.addr.ess;
  # Deny access to others
  deny all;

  # Nginx statistics
  location = /ns {
   # Enable the status handler
   stub_status on;
  }
 }
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=nginx_status,/etc/zabbix/nginx_stat.sh
```

Restarting services

```
service nginx reload; service zabbix-agent restart
```

## Oracle template mytemplate-oracle-trap.xml

Script of sending statistics of the Oracle server to the Zabbix server

```
chmod 750 /etc/zabbix/{oracle_stat.sh,oraenv}
chgrp zabbix /etc/zabbix/{oracle_stat.sh,oraenv}
```

Adding a user, under which the zabbix agent is running, to the group to access SQL Plus

```
usermod --append --groups oinstall zabbix
```

`/etc/zabbix/oraenv` - set Oracle environment variables

```
export ORACLE_HOME=
export PATH=$PATH:$ORACLE_HOME/bin
export NLS_LANG=
export TZ=
```

In the script in line

```
conn monitoring_user/Monitoring_password
```

set your values `Monitoring_user` and `Monitoring_password`.

Creating an Oracle user and assigning it rights for all databases.
The database is specified by setting the ORACLE_SID variable to its SID before running sqlplus

```
su - oracle
 export ORACLE_SID=
 sqlplus /nolog
  CONNECT / AS sysdba
  CREATE USER monitoring_user IDENTIFIED BY Monitoring_password;
  GRANT CONNECT TO Monitoring_user;
  GRANT SELECT ON v_$instance TO Monitoring_user;
  GRANT SELECT ON v_$sysstat TO Monitoring_user;
  GRANT SELECT ON v_$session TO Monitoring_user;
  GRANT SELECT ON dba_free_space TO Monitoring_user;
  GRANT SELECT ON dba_data_files TO Monitoring_user;
  GRANT SELECT ON dba_tablespaces TO Monitoring_user;
  GRANT SELECT ON dba_temp_files TO Monitoring_user;
  GRANT SELECT ON v_$log TO Monitoring_User;
  GRANT SELECT ON v_$archived_log TO Monitoring_user;
  GRANT SELECT ON v_$loghist TO Monitoring_user;
  GRANT SELECT ON v_$system_event TO Monitoring_user;
  GRANT SELECT ON v_$event_name TO Monitoring_user;
  GRANT SELECT ON v_$sort_segment TO Monitoring_user;
  GRANT SELECT ON v_$resource_limit TO Monitoring_user;
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=oracle_status[*],/etc/zabbix/oracle_stat.sh $1
UserParameter=oracle.discovery_databases,/etc/zabbix/oracle_stat.sh
UserParameter=oracle.discovery_tablespaces,/etc/zabbix/oracle_stat.sh tablespaces
```

Agent restart

```
service zabbix-agent restart
```

## Php-fpm, template mytemplate-php-fpm-trap.xml

Scenario of sending statistics of the php-fpm server to the Zabbix server

```
chmod 750 /etc/zabbix/php-fpm_stat.sh
chgrp zabbix /etc/zabbix/php-fpm_stat.sh
```

`/etc/nginx/nginx.conf` - add to the monitoring server (described in the nginx section)

```
  # Php-fpm statistics
  location = /ps {
   # Address: port or file of a UNIX socket of a FastCGI server
   fastcgi_pass unix: /var/run/www-fpm.sock;
   # Enable file common parameters FastCGI
   include fastcgi_params;
   # Parameters passed to the FastCGI server
   fastcgi_param SCRIPT_FILENAME ps;
  }
```

`/etc/php-fpm.d/www.conf` - in pool configuration

```
; ### Link to FPM status page; not set - status page not
; displayed ()
pm.status_path = /ps
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=php-fpm_status,/etc/zabbix/php-fpm_stat.sh
```

Restarting services

```
service nginx reload; service php-fpm reload; service zabbix-agent restart
```

## Postfix, template mytemplate-postfix-trap.xml

Install the `postfix-perl-scripts` package.
The abbreviated `logtail.pl` from the` logcheck` package is used.

Scenario of sending Postfix server statistics to Zabbix server

```
chmod 750 /etc/zabbix/{logtail.pl,postfix_stat.sh}
chgrp zabbix /etc/zabbix/{logtail.pl,postfix_stat.sh}
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=postfix_status,/etc/zabbix/postfix_stat.sh
```

`/etc/sudoers` - run logtail as root for zabbix

```
### Agent Zabbix
Defaults: zabbix !requiretty
zabbix ALL=(ALL) NOPASSWD: /etc/zabbix/logtail.pl -l /var/log/maillog -o /tmp/postfix_stat.dat
```

Agent restart

```
service zabbix-agent restart
```

## RabbitMQ, mytemplate-rabbitmq-trap.xml template

Scenario of sending RabbitMQ server statistics to Zabbix server

```
chmod 750 /etc/zabbix/{JSON.sh,rabbitmq_stat.sh}
chgrp zabbix /etc/zabbix/{JSON.sh,rabbitmq_stat.sh}
```

In the script in the substring

```
... --user Monitoring_user:Monitoring_password ...
```

set your values `Monitoring_user` and `Monitoring_password`.

Note: in the script, access to statistics via https protocol that is configured
in `/etc/rabbitmq/rabbitmq.config` in the rabbit section

```
  %% SSL Settings
  {ssl_options, [
   %% Full name of certificate authority certificate file in PEM format
   {cacertfile, "/etc/pki/tls/certs/CA.pem_certificate_file"},
   %% Full PEM certificate file name
   {certfile, "/etc/pki/tls/certs/Certificate_file.pem"},
   %% Full name of the PEM format private key file
   {keyfile, "/etc/pki/tls/private/Key_file.pem"},
   %% SSL Version Used
   {versions, ['tlsv1.2']},
   %% Used cipher suites
   {ciphers, [{ecdhe_rsa, aes_128_gcm, null, sha256}]},
   %% Client Certificate Verification
   {verify, verify_peer},
   %% Barring a client without a certificate
   {fail_if_no_peer_cert, false}
  ]},
```

For http-access to statistics, correct the protocol and remove the parameters
'ciphers', 'insecure' and 'tlsv1.2' per line

```
 RespStr = $(/usr/bin/curl --max-time 20 --no-keepalive --silent --ciphers ecdhe_rsa_aes_128_gcm_sha_256 --insecure --tlsv1.2 --user monitoring_user:Monitoring_password "https://127.0.0.1:15672/api/$1"| /etc/zabbix/JSON.sh -l 2>/dev/null)
```

`/etc/rabbitmq/enabled_plugins` - add a `rabbitmq_management` control plugin

```
[...,rabbitmq_management].
```

RabbitMQ monitoring user

```
rabbitmqctl add_user Monitoring_user Monitoring_password
rabbitmqctl set_user_tags Monitoring_user monitoring
rabbitmqctl set_permissions Monitoring_user '' '' ''
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=rabbitmq_status,/etc/zabbix/rabbitmq_stat.sh
UserParameter=rabbitmq.discovery_queues,/etc/zabbix/rabbitmq_stat.sh queues
```

Agent restart

```
service zabbix-agent restart
```

## Redis, template mytemplate-redis-trap.xml

Scenario of sending statistics of Redis server to Zabbix server

```
chmod 750 /etc/zabbix/redis_stat.sh
chgrp zabbix /etc/zabbix/redis_stat.sh
```

In the script in the substring

```
... -s /full/name/file/socket ...
```

set `/full/name/file/socket`.

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=redis_status,/etc/zabbix/redis_stat.sh
UserParameter=redis.discovery_db,/etc/zabbix/redis_stat.sh db
```

Agent restart

```
service zabbix-agent restart
```

## Sphinx, template mytemplate-sphinx-trap.xml

`/etc/sphinx/sphinx.conf` - local MySQL connection in the searchd section

```
 listen = 127.0.0.1:9306:mysql41
```

Scenario of sending statistics of Sphinx server to Zabbix server

```
chmod 750 /etc/zabbix/sphinx_stat.sh
chgrp zabbix /etc/zabbix/sphinx_stat.sh
```

`/etc/zabbix/zabbix_agentd.conf` - script connection to zabbix agent

```
UserParameter=sphinx_status,/etc/zabbix/sphinx_stat.sh
UserParameter=sphinx.discovery_indexes,/etc/zabbix/sphinx_stat.sh indexes
```

Restarting services

```
service searchd restart; service zabbix-agent restart
```

# Linux (CentOS 7.X)

The scenarios and their installation is similar to CentOS 6.X with minor changes:

- The inclusion, restart and overload of services is performed by systemd.
For example, restarting agent

```
systemctl restart zabbix-agent.service
```

- The "disk I/O" script is different - `io_stat.sh` - located in
 subdirectory `Scripts/CentOS7`

# Windows (Server 2012R2)

Scenarios:
- written in Powershell;
- get data using PowerShell methods or a regular client of the service;
- filter/process data using PowerShell methods;
- send data to zabbix_sender;
- placed in the `c:\Scripts` directory.

Installation:

- Copy `zabbix_agentd.exe`, `zabbix_sender.exe`, `zabbix_agentd_win.conf` to
   `c:\Scripts`;

- Agent settings in the file `c:\Scripts\zabbix_agentd_win.conf`:

```
 SourceIP = IP.address.zabbix.agent
 Server = IP.address.zabbix.server
 ListenIP = IP.address.zabbix.agent
 ServerActive = IP.zabbix.server
 Hostname = DNS.server.name
 Timeout = 10
```

- Resolution of ports in Windows Firewall:

```
 Inbound rules - Create a rule ...
  Rule type For port
  Protocol and ports
   TCP protocol
   Specific local ports 10050
  Act
   Allow connection
  Profile
   Domain
   Private
  Name:
   Zabbix agent name
 Zabbix Agent - Properties - Area - Remote IP Address
  The specified IP addresses are IP.address.zabbix.server
```

- Installation service. Command line - Run as administrator:

```
  c:\Scripts\zabbix_agentd.exe --config c:\Scripts\zabbix_agentd_win.conf --install
```

- Allow execution of unsigned scripts.
 Run `powershell.exe` as **Administrator**:

```
 PS > Set-ExecutionPolicy remotesigned
```

- Install the required scripts.

## PostgreSQL template mytemplate-windows-postgresql-trap.xml

PostgreSQL (from 1C) is installed in the directory `E:\PostgreSQL\9.4.2-1.1C`.

User monitoring

```
E:\PostgreSQL\9.4.2-1.1C\bin\psql --username=postgres template1
template1=# CREATE USER zabbix;
template1=# \q
```

Access without a password to the monitoring user first line in
`E:\PostgreSQL\9.4.2-1.1C\data\pg_hba.conf`

```
host template1 zabbix 127.0.0.1/32 trust
```

Restart PostgreSQL
`Services - PostgreSQL Database Server - Restarting Service`

In the monitoring script `c:\Scripts\postgresql_stat.ps1`:
- save the full name of the executable file of the PostgreSQL client in the variable `$ PsqlExec`;
- in the startup line `zabbix_sender` parameter` host` set in the DNS-name of the server.

`c:\Scripts\zabbix_agentd_win.conf` - connect script to zabbix agent

```
UserParameter=postgresql_status, powershell -File "c:\Scripts\postgresql_stat.ps1"
UserParameter=postgresql.discovery_databases, powershell -File "c:\Scripts\postgresql_stat.ps1" db
```

Agent restart
`Services - Zabbix Agent - Restart Service`

## RabbitMQ, mytemplate-rabbitmq-trap.xml template

Erlang `otp_win64_19.0.exe` is assumed.

In the file enabled_plugins - add the rabbitmq_management control plugin

```
[..., rabbitmq_management].
```

User monitoring

```
SET ERLANG_HOME = c:\Program Files\erl8.0
cd "c:\Program Files\RabbitMQ Server\rabbitmq_server-3.6.5\sbin"
rabbitmqctl add_user Monitoring_user Monitoring_password
rabbitmqctl set_user_tags Monitoring_user monitoring
rabbitmqctl set_permissions Monitoring_user '' '' ''
```

Restart RabbitMQ
`Services - RabbitMQ - Restart Service`

In the RabbitMQ monitoring script, `c:\Scripts\rabbitmq_stat.ps1`:
- in line

```
   $ wc.Credentials = New-Object System.Net.NetworkCredential ('Monitoring_user', 'Monitoring_password')
```

  set your values `Monitoring_user` and `Monitoring_password`.
- in the startup line `zabbix_sender` parameter` host` set in the DNS-name of the server.

Note: in the script, access to statistics via https protocol that is configured
in rabbitmq.config in the rabbit section

```
  %% SSL Settings
  {ssl_options, [
   %% Full name of certificate authority certificate file in PEM format
   {cacertfile, "CA_pe_file_CA.pem"},
   %% Full PEM certificate file name
   {certfile, "Certificate_file.pem"},
   %% Full name of the PEM format private key file
   {keyfile, "Keyfile.pem"},
   %% SSL Version Used
   {versions, ['tlsv1.1']},
   %% Client Certificate Verification
   {verify, verify_peer},
   %% Barring a client without a certificate
   {fail_if_no_peer_cert, false}

  ]},
```

For http access to statistics, fix the protocol in the string

```
 $ uri = New-Object System.Uri ("https://127.0.0.1:15672/api/$Query");
```

and delete rows

```
[System.Net.ServicePointManager] :: ServerCertificateValidationCallback = {$ true}
[System.Net.ServicePointManager] :: SecurityProtocol = [System.Net.SecurityProtocolType] :: Tls11
```

`c:\Scripts\zabbix_agentd_win.conf` - connect script to zabbix agent

```
UserParameter=rabbitmq_status, powershell -File "c:\Scripts\rabbitmq_stat.ps1"
UserParameter=rabbitmq.discovery_queues, powershell -File "c:\Scripts\rabbitmq_stat.ps1" queues
```

Agent restart
`Services - Zabbix Agent - Restart Service`
