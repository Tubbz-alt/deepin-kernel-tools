#!/bin/bash

. /etc/deepin-sleep/deepin-sleep.conf

BoolIsOn() {
    local val
    val=$(echo $1 | tr '[A-Z]' '[a-z]')
    [ "$val" = "on" ] && return 0
    [ "$val" = "yes" ] && return 0
    [ "$val" = "true" ] && return 0
    [ "$val" = "1" ] && return 0
    [ "$val" = "no" ] && return 1
    [ "$val" = "off" ] && return 1
    [ "$val" = "false" ] && return 1
    [ "$val" = "0" ] && return 1
    echo "$1 is not bool"
    exit 1
}

BLACKLIST_FILE="/etc/deepin-sleep/blacklisted-modules"
VBETOOL_VCSADATA="/tmp/deepin-sleep-vcsadata"
VBETOOL_SAVE_STATE="/tmp/deepin-sleep-state"
VBETOOL_ORIGCONSOLE="/tmp/deepin-sleep-origconsole"
VBETOOL_VT=61

[ -f $BLACKLIST_FILE ] || exit 1

blacklistedmodules=$(cat $BLACKLIST_FILE)
modules=""

UnloadModules() {
#    nmcli networking off
#    /usr/bin/dbus-send --system \
#        --dest=org.freedesktop.NetworkManager \
#        --type=method_call /org/freedesktop/NetworkManager \
#        org.freedesktop.NetworkManager.sleep
    BoolIsOn $UnloadBlacklistedModules || return 0
    [ -z "$blacklistedmodules" ] && return 0

    for mod in $blacklistedmodules; do
        if ! grep -q "^$mod " /proc/modules; then
            echo "$mod not loaded"
            continue
        fi

        echo "Unloading module $mod"
        /sbin/modprobe -r $mod || echo "Unload $mod failed!"
        modules="$modules $mod"
    done
    echo "$modules" > /tmp/deepin-sleep-unloaded-modules
}

LoadModules() {
    BoolIsOn $UnloadBlacklistedModules || return 0
    modules=$(cat /tmp/deepin-sleep-unloaded-modules)
    for mod in $modules; do
        echo "Loading module $mod"
        /sbin/modprobe $mod
    done
    rm -fr /tmp/deepin-sleep-unloaded-modules

#    /usr/bin/dbus-send --system \
#        --dest=org.freedesktop.NetworkManager \
#        --type=method_call /org/freedesktop/NetworkManager \
#        org.freedesktop.NetworkManager.wake
#    nmcli networking on
}

VbetoolSaveState() {
    if BoolIsOn $RestoreVCSAData; then
        if [ -r /dev/vcsa ] ; then
            cat /dev/vcsa > $VBETOOL_VCSADATA
        else
            echo "/dev/vcsa not found or not readable. Not saving"
        fi
    fi

    BoolIsOn $EnableVbetool || return 0

    if ! command -v vbetool > /dev/null 2>&1 ; then
        echo "vbetool is not installed"
        return 0
    fi

#    [ -f $RestoreVbeStateFrom ] && return 0

    VBETOOL_ORIG_VT=$(fgconsole 2>/dev/null) || VBETOOL_ORIG_VT=1
    chvt $VBETOOL_VT
    echo "$VBETOOL_ORIG_VT" > $VBETOOL_ORIGCONSOLE
    vbetool vbestate save > $VBETOOL_SAVE_STATE || return 1
    return 0
}

VbetoolRestoreState() {
    if BoolIsOn $RestoreVCSAData; then
        if [ -r $VBETOOL_VCSADATA ] ; then
            echo "Restoring VCSA data"
            cat $VBETOOL_VCSADATA > /dev/vcsa
            rm -fr $VBETOOL_VCSADATA
        fi
    fi

    BoolIsOn $EnableVbetool || return 0

    if ! command -v vbetool > /dev/null 2>&1 ; then
        echo "vbetool not installed"
        return 0
    fi

    if BoolIsOn $VbetoolPost; then
        sleep 5
        echo "posting GPU"
        vbetool post
    fi

#    if [ -r $RestoreVbeStateFrom ]; then
#        vbetool vbestate restore < $RestoreVbeStateFrom
    if [ -r $VBETOOL_SAVE_STATE ]; then
        echo "Restoring GPU state"
        vbetool vbestate restore < $VBETOOL_SAVE_STATE
        rm -fr $VBETOOL_SAVE_STATE
    fi

    echo "Turning on monitor" 
    vbetool dpms on

    if [ -r $VBETOOL_ORIGCONSOLE ]; then
        VBETOOL_ORIG_VT=$(cat $VBETOOL_ORIGCONSOLE)
        chvt $VBETOOL_ORIG_VT
        rm -fr $VBETOOL_ORIGCONSOLE
    fi
}

case $1 in
pre)
    UnloadModules
    VbetoolSaveState
    ;;
post)
    LoadModules
    VbetoolRestoreState
    ;;
esac
