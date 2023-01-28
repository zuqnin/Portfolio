#!/bin/bash

cat >> /opt/mhdd-automation/hosts/master-haproxy.sql << EOF
CREATE USER 'haproxy'@'$ip_haproxy_node_1';
GRANT ALL PRIVILEGES ON *.* TO 'haproxy'@'$ip_haproxy_node_1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

cat >> /opt/mhdd-automation/hosts/second-haproxy.sql << EOF
CREATE USER 'haproxy'@'$ip_haproxy_node_2';
GRANT ALL PRIVILEGES ON *.* TO 'haproxy'@'$ip_haproxy_node_2' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
