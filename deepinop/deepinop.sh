#!/bin/bash

nr_cpus=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
((mask=(1<<${nr_cpus})-1))

# io optimization
disks=$(cat /proc/mounts  | grep "^\/dev" | awk //'{print $1}' | sed 's,\/dev\/\([^0-9]*\)[0-9]*,\1,g' | sort -u)

kversion=$(uname -r | sed -ne 's,\(^[0-9]\.[0-9]\.[0-9]-[0-9]\).*$,\1,p')

for disk in $disks; do
    echo 0 > /sys/class/block/$disk/queue/iosched/slice_idle
    echo 0 > /sys/block/$disk/queue/iosched/low_latency
    if [[ "$kversion" < "4.4.0-3" ]]; then
        echo 32 > /sys/block/$disk/queue/iosched/quantum 
        echo 400 >  /sys/class/block/$disk/queue/iosched/slice_sync
    fi
    echo 4096 > /sys/class/block/$disk/queue/nr_requests
    echo 4096 > /sys/class/block/$disk/queue/read_ahead_kb
    echo 16 > /sys/class/block/$disk/queue/iosched/back_seek_penalty
    echo `cat /sys/class/block/$disk/queue/max_hw_sectors_kb` > /sys/class/block/$disk/queue/max_sectors_kb
done

# network optimization
# ethtool adjust hardware queue length.

# prefer low latency to high throughput
# sysctl -w net.ipv4.tcp_low_latency=1
# ethtool -G eth0 rx 4096 tx 4096

interfaces=$(ip addr | grep "^[0-9]\+:" | awk //'{print $2}' | sed 's,:,,g')

for interface in $interfaces; do
    if [ "x$interface" != "xlo" ]; then
        echo 4096 > /sys/class/net/$interface/tx_queue_len
        queues=$(ls /sys/class/net/$interface/queues)
        for queue in $queues; do
            tmp=$(echo $queue | sed 's,^rx-.*,,g')
            if [ -z "$tmp" ]; then
                echo $mask > /sys/class/net/$interface/queues/$queue/rps_cpus
                echo 8192 > /sys/class/net/$interface/queues/$queue/rps_flow_cnt
            else 
                echo $mask > /sys/class/net/$interface/queues/$queue/xps_cpus
            fi
        done
    fi
done

sysctl -w net.core.flow_limit_cpu_bitmap=$mask
sysctl -w net.core.flow_limit_table_len=8192
sysctl -w net.core.rps_sock_flow_entries=8192
sysctl -w net.core.busy_read=50
sysctl -w net.core.busy_poll=100
sysctl -w net.core.dev_weight=512
sysctl -w net.core.rmem_max=2097152
sysctl -w net.core.rmem_default=2097152
sysctl -w net.core.wmem_max=2097152
sysctl -w net.core.wmem_default=2097152
sysctl -w net.core.message_burst=50
sysctl -w net.core.message_cost=1
sysctl -w net.core.netdev_budget=1024
sysctl -w net.core.netdev_max_backlog=8000
sysctl -w net.core.netdev_tstamp_prequeue=1
sysctl -w net.core.optmem_max=524288
sysctl -w net.core.somaxconn=512
sysctl -w net.ipv4.tcp_fin_timeout=40
sysctl -w net.ipv4.tcp_invalid_ratelimit=2000
sysctl -w net.ipv4.tcp_max_syn_backlog=2048
sysctl -w net.ipv4.tcp_tw_recycle=1
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_thin_linear_timeouts=1
sysctl -w net.ipv4.tcp_thin_dupack=1
sysctl -w net.ipv4.tcp_limit_output_bytes=1048576
sysctl -w net.ipv4.icmp_errors_use_inbound_ifaddr=1
