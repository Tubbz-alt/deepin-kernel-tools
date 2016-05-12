#!/bin/bash

vga_path="/sys/kernel/debug/vgaswitcheroo/switch"

if [ -e $vga_path ]; then
    echo ON > $vga_path
fi
