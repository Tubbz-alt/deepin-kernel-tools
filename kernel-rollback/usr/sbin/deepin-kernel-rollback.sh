#!/bin/bash

set -e

old_kernel=$(grub-editenv list | grep oldkernel | awk -F'=' //'{print $2}')

cur_kernel=$(md5sum /boot/vmlinuz-$(uname -r) | awk //'{print $1}')

new_release=$(cat /boot/grub/grub.cfg | sed -e '1,/^menuentry/d' | sed -e '/^submenu/,$d' | grep  "/boot/vmlinuz" | awk //'{print $2}' | sed -e 's,\/boot\/vmlinuz-,,')

new_kernel="linux-image-${new_release}"

if [ "x${old_kernel}" != "x${cur_kernel}" ]; then
	# new kernel up and running
	grub-set-default '0'
else
	# into old kernel, notify user to remove new kernel?
	echo "New kernel failed! Remove new kernel: ${new_kernel}"
	apt purge -y ${new_kernel}
fi

grub-editenv - unset oldkernel

systemctl disable deepin-kernel-rollback
