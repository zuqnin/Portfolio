#!/bin/bash

read -p "MariaDB node1 (master) ip address: " ip_node_1
read -p "MariaDB node2 (replica node) ip address: " ip_node_2
read -p "DNS Server + Grafana ip address: " dns_ip
read -p "HAProxy loadbalancer haproxy-node1 (manager) ip address: " ip_haproxy_node_1
read -p "HAProxy loadbalancer haproxy-node2 (worker) ip address" ip_haproxy_node_2

last_octet_ip_node_1=$(echo "$ip_node_1" | cut -d . -f 4)
last_octet_ip_node_2=$(echo "$ip_node_2" | cut -d . -f 4)
last_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 4)
last_octet_ip_haproxy_node_1=$(echo "$ip_haproxy_node_1" | cut -d . -f 4)
last_octet_ip_haproxy_node_2=$(echo "$ip_haproxy_node_2" | cut -d . -f 4)

first_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 1)
second_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 2)
third_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 3)

echo "[DNS]\ndns-server ansible_host=$dns_ip" > ansible-inventory/dns-server

echo -e "admin $dns_ip\nnode1 $ip_node_1\nnode2 $ip_node_2\nhaproxy-node1 $ip_haproxy_node_1\nhaproxy-node2 $ip_haproxy_node_2" >> /opt/hosts.txt

echo -e "nameserver $dns_ip\ndomain  server.local" > /opt/resolv.conf

export ip_haproxy_node_1=$ip_haproxy_node_1
export ip_haproxy_node_2=$ip_haproxy_node_2
export ip_node_1=$ip_node_1

echo "if 'PermitRootLogin yes' is set in the sshd_config file at the address where you want to set up a DNS server: "

echo "1) Type 'yes/y' if you want to take the ip/prefix information from the host using script"

echo "2) Type 'no/n' if you want to write manually"

read -p "Choose (yes/y or no/n): " answer

case $answer in

        yes|y)
                subnet_prefix=$(ssh root@$dns_ip "echo $(ip route | sed -n '2p' | awk '{print $1}')")
                export subnet_prefix
                ;;

        no|n)
                read -p "Enter ip/prefix (example: 192.168.1.0/24, using command ip route to see what is ip/prefix): " subnet_prefix
                export subnet_prefix
esac

echo "dns_ip: $dns_ip" >> ansible-inventory/node_vars.yml
echo "dns_server_ip_prefix:  $subnet_prefix" >> ansible-inventory/node_vars.yml

cat >> /opt/named.conf << EOF

//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//

options {
//      listen-on port 53 { 127.0.0.1; };
//      listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        secroots-file   "/var/named/data/named.secroots";
        recursing-file  "/var/named/data/named.recursing";
        allow-query     { localhost; $subnet_prefix; };

        /* 
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable 
           recursion. 
         - If your recursive DNS server has a public IP address, you MUST enable access 
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification 
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface 
        */
        recursion yes;

        dnssec-validation yes;

        managed-keys-directory "/var/named/dynamic";
        geoip-directory "/usr/share/GeoIP";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";

        /* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
        include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

//FORWARD ZONE

zone "server.local" IN {
	type master;
	file "/var/named/server.local.db";
	allow-update { none; };
	allow-query { any; };
};

//BACKWARD ZONE

zone "$first_octet_dns_ip.$second_octet_dns_ip.$third_octet_dns_ip.in-addr.arpa" IN {
        type master;
        file "/var/named/reverse.zone.db";
        allow-update { none; };
        allow-query { any; };
};

EOF

cat >> /opt/server.local.db << EOF
$TTL 86400
@       IN      SOA     ns.server.local.        root.server.local. (
                2020011800 ;Serial
                3600 ;Refresh
                1800 ;Retry
                604800 ;Expire
                86400 ;Minimum TTL
)

@       IN      NS      ns.server.local.
ns.server.local.        IN      A       $dns_ip
ns      IN      A       $dns_ip
admin   IN      CNAME   ns
node1  IN      A       $ip_node_1
node2  IN      A       $ip_node_2
haproxy-node1 IN  A       $ip_haproxy_node_1
haproxy-node2 IN  A       $ip_haproxy_node_2


EOF
cat >> /opt/reverse.zone.db << EOF
$TTL 86400
@	IN	SOA	ns.server.local.	root.server.local. (
		2020011800 ;Serial
		3600 ;Refresh
		1800 ;Retry
		604800 ;Expire
		86400 ;Minimum TTL
)

@	IN	NS	ns.server.local.
ns	IN	A	$dns_ip
admin	IN	CNAME	ns
$last_octet_dns_ip	IN	PTR	ns.server.local.
$last_octet_ip_node_1   IN  PTR node1.server.local
$last_octet_ip_node_2   IN  PTR node2.server.local
$last_octet_ip_haproxy_node1 IN  PTR haproxy-node1.server.local
$last_octet_ip_haproxy_node_2 IN  PTR haproxy-node2.server.local
EOF



