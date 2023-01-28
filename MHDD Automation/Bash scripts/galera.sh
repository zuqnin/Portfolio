#!/bin/bash


cat >> /opt/mhdd-automation/mariadb-confs/master-node1.cnf << EOF

[mysqld]

binlog_format=ROW

default-storage-engine=innodb

innodb_autoinc_lock_mode=2

bind-address=0.0.0.0

wsrep_on=1

wsrep_provider=/usr/lib64/galera/libgalera_smm.so

#wsrep_provider_options=

wsrep_cluster_name="galera_cluster"

wsrep_cluster_address="gcomm://"

# wsrep_node_name=""

# wsrep_node_address=""

wsrep_node_incoming_address=

wsrep_slave_threads=1

#wsrep_dbug_option

wsrep_certify_nonPK=1

wsrep_max_ws_rows=0

wsrep_max_ws_size=2147483647

wsrep_debug=0

wsrep_convert_LOCK_to_trx=0

wsrep_retry_autocommit=1

wsrep_auto_increment_control=1

wsrep_drupal_282555_workaround=0

wsrep_causal_reads=0

wsrep_notify_cmd=

wsrep_sst_method=rsync

# wsrep_sst_receive_address=

wsrep_sst_auth=root:

#wsrep_sst_donor=

#wsrep_sst_donor_rejects_queries=0

# wsrep_protocol_version=
EOF

cat >> /opt/mhdd-automation/mariadb-confs/slave-node2.cnf << EOF

[mysqld]

binlog_format=ROW

default-storage-engine=innodb

innodb_autoinc_lock_mode=2

bind-address=0.0.0.0

wsrep_on=1

wsrep_provider=/usr/lib64/galera/libgalera_smm.so

# wsrep_provider_options=

wsrep_cluster_name="galera_cluster"

wsrep_cluster_address="gcomm://$ip_node_1"

#wsrep_node_name=""

#wsrep_node_address=""

#wsrep_node_incoming_address=

wsrep_slave_threads=1

#wsrep_dbug_option

wsrep_certify_nonPK=1

wsrep_max_ws_rows=0

wsrep_max_ws_size=2147483647

wsrep_debug=0

wsrep_convert_LOCK_to_trx=0

wsrep_retry_autocommit=1

wsrep_auto_increment_control=1

wsrep_drupal_282555_workaround=0

wsrep_causal_reads=0

wsrep_notify_cmd=

wsrep_sst_method=rsync

#wsrep_sst_receive_address=

wsrep_sst_auth=root:

#wsrep_sst_donor=

#wsrep_sst_donor_rejects_queries=0

# wsrep_protocol_version=

EOF