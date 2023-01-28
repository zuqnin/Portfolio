#!/bin/bash

cat >> /usr/sbin/haproxy-backup.sh << EOF
#!/bin/bash

ip_addr=192.168.1.107
ip_addr_backup=192.168.1.109
timer=$(date +%Y-%m-%d'/'%H-%M-%S)
server_down=$(ping -c 5 $ip_haproxy_node_1 > /dev/null 2>&1; echo $?)
case $server_down in
        0)
          echo "$timer The $ip_haproxy_node_1 host where docker is running is alive." >> /var/log/haproxy-status.log
          ssh root@$ip_haproxy_node_1 'systemctl start docker; docker inspect db_proxy | grep "db_proxy"' > /dev/null 2>&1
          if [ "$?" = 0 ]; then
                    run_check=$(ssh root@$ip_haproxy_node_1 "docker container inspect -f '{{.State.Status}}' db_proxy | grep -i 'running\|exited'")
                    case $run_check in
                            running)
                                    echo "$timer db_proxy container is running in master node." >> /var/log/haproxy-status.log
                                    ;;
                            exited)
                                    ssh root@$ip_haproxy_node_1 "docker rm db_proxy; docker run -it --name db_proxy --network host -v /tmp/haproxy/:/usr/local/etc/haproxy/ -d haproxytech/haproxy-alpine" > /dev/null 2>&1
                                    echo "$timer Old db_proxy is in exited mode. New db_proxy container is created." >> /var/log/haproxy-status.log
                                    ;;
                    esac

          else
                    echo "$timer db_proxy container not exist in master node. Creating db_proxy container..." >> /var/log/haproxy-status.log
                    ssh root@$ip_haproxy_node_1 "docker run -it --name db_proxy --network host -v /tmp/haproxy/:/usr/local/etc/haproxy/ -d haproxytech/haproxy-alpine" > /dev/null 2>&1
                    ssh root@$ip_haproxy_node_1 "docker inspect db_proxy | grep 'db_proxy'" > /dev/null 2>&1
                    if [ "$?" = 0 ]; then
                            echo "$timer db_proxy container is created and running in master node." >> /var/log/haproxy-status.log
                    else
                            echo "$timer Check why container is not running in master node." >> /var/log/haproxy-status.log
                    fi
          fi
          ;;  
        *)
            echo "$timer The $ip_haproxy_node_1 host where docker is running is dead. Second HAProxy server in $ip_haproxy_node_2 is activating..." >> /var/log/haproxy-status.log
            ssh root@$ip_haproxy_node_2 "systemctl start docker; docker run -it --name db_proxy --network host -v /tmp/haproxy/:/usr/local/etc/haproxy/ -d haproxytech/haproxy-alpine" > /dev/null
            state=$(ssh root@$ip_haproxy_node_2 "docker container inspect -f '{{.State.Status}}' db_proxy")
            if [ $state="running" ];then
               echo -e "$timer Second HAProxy server is active" >> /var/log/haproxy-status.log
            else
                echo -e "$timer Second server is not working. Check it." >> /var/log/haproxy-status.log
            fi
            ;;
esac
EOF

cat >> /etc/systemd/system/haproxy-backup.service << EOF
[Unit]
Description=Script for HAProxy failure

[Service]
ExecStart=/bin/bash /usr/sbin/haproxy-backup.sh

[Install]
WantedBy=default.target
EOF

cat >> /etc/systemd/system/haproxy-backup.timer << EOF
[Unit]
Description=Schedule a script every 1 minute
#Allow manual starts
RefuseManualStart=no
#Allow manual stops
RefuseManualStop=no

[Timer]
#Execute job if it missed a run due to machine being off
Persistent=true
#Run 120 seconds after boot for the first time
OnBootSec=120
#Run every 1 minute thereafter
OnUnitActiveSec=60
#File describing job to execute
Unit=haproxy-backup.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload

systemctl enable haproxy-backup.service

systemctl start haproxy-backup.service

systemctl enable haproxy-backup.timer

systemctl start haproxy-backup.timer
