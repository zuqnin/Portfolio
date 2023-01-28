#!/bin/bash

read -p "MariaDB node1 (master) ip address: " ip_node_1
read -p "MariaDB node2 (replica node) ip address: " ip_node_2
read -p "DNS Server + Grafana ip address: " dns_ip
read -p "HAProxy loadbalancer haproxy-node1 (manager) ip address: " ip_haproxy_node_1
read -p "HAProxy loadbalancer haproxy-node2 (worker) ip address" ip_haproxy_node_2
read -p "Controller ip address" ip_controller

last_octet_ip_node_1=$(echo "$ip_node_1" | cut -d . -f 4)
last_octet_ip_node_2=$(echo "$ip_node_2" | cut -d . -f 4)
last_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 4)
last_octet_ip_haproxy_node_1=$(echo "$ip_haproxy_node_1" | cut -d . -f 4)
last_octet_ip_haproxy_node_2=$(echo "$ip_haproxy_node_2" | cut -d . -f 4)
last_octet_ip_controller=$(echo "$ip_controller" | cut -d . -f 4)

first_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 1)
second_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 2)
third_octet_dns_ip=$(echo "$dns_ip" | cut -d . -f 3)

mkdir -p /opt/mhdd-automation/ansible-inventory
mkdir -p /opt/mhdd-automation/hosts
mkdir -p /opt/mhdd-automation/resolv-file
mkdir -p /opt/mhdd-automation/dns-confs
mkdir -p /opt/mhdd-automation/mariadb-confs

echo -e "$dns_ip\n$ip_haproxy_node_1\n$ip_haproxy_node_2\n$ip_node_1\n$ip_node_2\n$ip_controller" > /opt/mhdd-automation/hosts/servers-ip.txt

echo -e "ns.server.local\nnode1.server.local\nnode2.server.local\nhaproxy-node1.server.local\nhaproxy-node2.server.local\ncontroller.server.local" > /opt/mhdd-automation/hosts/servers-dns.txt

echo -e "[DNS]\ndns-server ansible_host=ns.server.local\n[haproxy]\nhaproxy-node1 ansible_host=haproxy-node1.server.local\nhaproxy-node2 ansible_host=haproxy-node2.server.local\n[clusters]\nnode1 ansible_host=node1.server.local\nnode2 ansible_host=node2.server.local\n[controller]\ncontroller ansible_host=controller.server.local" > /opt/mhdd-automation/hosts/all-node-dns

echo -e "[clusters]\nnode1 ansible_host=node1.server.local\nnode2 ansible_host=node2.server.local" >> /opt/mhdd-automation/ansible-inventory/mariadb-clusters

echo -e "[haproxy]\nhaproxy-node1 ansible_host=haproxy-node1.server.local\nhaproxy-node2 ansible_host=haproxy-node2.server.local" /opt/mhdd-automation/ansible-inventory/haproxy-nodes

servers_file=/opt/mhdd-automation/hosts/servers-ip.txt

while IFS= read -r server
do
        ssh-copy-id root@$server
done < "$servers_file"

echo -e "[DNS]\ndns-server ansible_host=$dns_ip\n[haproxy]\nhaproxy-node1 ansible_host=$ip_haproxy_node_1\nhaproxy-node2 ansible_host=$ip_haproxy_node_2\n[clusters]\nnode1 ansible_host=$ip_node_1\nnode2 ansible_host=$ip_node_2\n[controller]\ncontroller ansible_host=$ip_controller" >> /opt/mhdd-automation/ansible-inventory/all-node-ip

echo -e "[DNS]\ndns-server ansible_host=$dns_ip" > /opt/mhdd-automation/ansible-inventory/dns-server-ip

echo -e "admin $dns_ip\nnode1 $ip_node_1\nnode2 $ip_node_2\nhaproxy-node1 $ip_haproxy_node_1\nhaproxy-node2 $ip_haproxy_node_2\ncontroller $ip_controller" >> /opt/mhdd-automation/hosts/hosts.txt

echo -e "nameserver $dns_ip\ndomain  server.local" > /opt/mhdd-automation/resolv-file/resolv.conf

export ip_haproxy_node_1=$ip_haproxy_node_1
export ip_haproxy_node_2=$ip_haproxy_node_2
export ip_node_1=$ip_node_1
export ip_node_2=$ip_node_2

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

echo "dns_ip: $dns_ip" >> /opt/mhdd-automation/ansible-inventory/node_vars.yml
echo "dns_server_ip_prefix:  $subnet_prefix" >> /opt/mhdd-automation/ansible-inventory/node_vars.yml
echo "haproxy_node1: $ip_haproxy_node_1" >> /opt/mhdd-automation/ansible-inventory/node_vars.yml
echo "haproxy_node2: $ip_haproxy_node_2" >> /opt/mhdd-automation/ansible-inventory/node_vars.yml

cat >> /opt/mhdd-automation/dns-confs/named.conf << EOF

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

cat >> /opt/mhdd-automation/dns-confs/server.local.db << EOF
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
controller    IN  A       $ip_controller
EOF

cat >> /opt/mhdd-automation/dns-confs/reverse.zone.db << EOF
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
$last_octet_ip_haproxy_node_1 IN  PTR haproxy-node1.server.local
$last_octet_ip_haproxy_node_2 IN  PTR haproxy-node2.server.local
$last_octet_ip_controller     IN  PTR controller.server.local
EOF

