#!/bin/bash

check_active_gpu() {
    vga_path="/sys/kernel/debug/vgaswitcheroo/switch"
    active_gpu=
    if [ -e $vga_path ]; then
        active_gpu=$(grep "+:Pwr" $vga_path | awk -F":" //'{print $2}' || :)
    fi
    echo $active_gpu
}

# echo ON > /sys/kernel/debug/vgaswitcheroo/switch
active_gpu=$(check_active_gpu)
if [ -n "$active_gpu" ]; then
    echo $active_gpu > /sys/kernel/debug/vgaswitcheroo/switch
    echo OFF > /sys/kernel/debug/vgaswitcheroo/switch
fi
