#!/bin/bash

servers_file=/opt/mhdd-automation/hosts/servers-dns.txt

while IFS= read -r server
do
        ssh-copy-id root@$server
done < "$servers_file"