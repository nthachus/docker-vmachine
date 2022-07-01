#!/bin/sh
set -xe

# cgroup_enable=memory ???
sed -i -e 's,/dev/usbdisk[ \t]*/media,#&,' \
    -e 's/\(modules *= *"[^"]*\), *usb-storage/\1/' -e 's/\(initfs_features *= *"[^"]*\) usb/\1/' \
    -e 's/kernel_opts *= *"[^"]*quiet/& swapaccount=1/' \
    -e 's/\(GRUB_TIMEOUT\) *= *[0-9]*$/\1=0/' /sbin/setup-disk

# Configure APK repositories
sed -i 's,"# *\([^"]*\}/community\)","\1",' /sbin/setup-apkrepos

# Additional packages
echo "apk update -q
    apk add --no-cache open-vm-tools openssh-server sudo iptables docker-engine

    rc-update add fuse boot
    rc-update add open-vm-tools boot
    rc-update add docker boot
    rc-update add netmount boot
    rc-update add sshd default

    addgroup -S docker
    adduser -g Docker -G docker -D docker
    echo 'docker:tcuser' | chpasswd
    adduser docker wheel
    adduser docker adm
    adduser docker vmware
    passwd -d root
    passwd -l root
" | sed -i '/^.*sshd.*= *"none".*/r /dev/stdin' /sbin/setup-sshd

# Format 2nd HDD
printf 'n\np\n1\n\n\nw\n' | fdisk /dev/sdb
sync


# Answer file for setup-alpine script (SWAP_SIZE -s 4096)
setup-alpine -c answer-file.cfg
sed -i -e 's/ alpine-test/ docker-alpine/' \
    -e 's/\(PROXYOPTS\) *=.*/\1="none"/' -e 's/\(APKREPOSOPTS\) *=.*/\1="-1"/' \
    -e 's/ \(openssh\|openntpd\)"/ none"/' -e 's/-m data /-m sys /' answer-file.cfg
echo 'y' | setup-alpine -e -f answer-file.cfg


# Post-installation
mount -t ext4 /dev/sda3 /mnt
rm -rf /mnt/var/cache/apk/* /mnt/tmp/*

# Configure Docker storage
mkdir -p /mnt/var/lib/docker
mkfs.ext4 /dev/sdb1 2>&1 | grep 'UUID:' | sed 's,.*UUID: *\([^ ]*\).*,UUID=\1\t/var/lib/docker\text4\tdefaults\t0 0,' \
    >> /mnt/etc/fstab

# Setup users
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /mnt/etc/sudoers.d/wheel
chmod 0440 /mnt/etc/sudoers.d/*


# Certificates
[ -s certificates.tgz ] || wget -q "http://$(ip r | grep '\.0/' | sed 's,\.0/.*,.1,'):8080/certificates.tgz" || true
[ ! -s certificates.tgz ] || tar -C /tmp -xf certificates.tgz

# Configure SSH service
sed -i 's/^# *\(PermitRootLogin\).*/\1 no/' /mnt/etc/ssh/sshd_config
cp -af /home/docker /mnt/home/
(
    cd /mnt/home/docker
    mkdir -p .ssh
    [ ! -s /tmp/id_rsa.pub ] || cp -pf /tmp/id_rsa.pub .ssh/authorized_keys

    chmod -R 0600 .ssh
    chmod 0700 .ssh
    chown -R docker: .ssh
)

#echo 'ip_tables' > /mnt/etc/modules-load.d/iptables.conf
sed -i 's/\(SAVE_RESTORE_OPTIONS\) *=.*/\1=""/' /mnt/etc/conf.d/iptables

# Configure Docker engine
[ ! -s /tmp/server-key.pem ] && \
    sed -i 's,\(_OPTS *= *"[^"]*\),\1 -H unix:// -H tcp://0.0.0.0:2375,' /mnt/etc/conf.d/docker || \
    sed -i 's,\(_OPTS *= *"[^"]*\),\1 -H unix:// -H tcp://0.0.0.0:2376 --tlsverify,' /mnt/etc/conf.d/docker
(
    cd /mnt/root
    mkdir -p .docker
    [ ! -s /tmp/ca.pem ] || cp -pf /tmp/ca.pem .docker/
    [ ! -s /tmp/server-key.pem ] || cp -pf /tmp/server-key.pem .docker/key.pem
    [ ! -s /tmp/server.pem ] || cp -pf /tmp/server.pem .docker/cert.pem

    chmod -R o-r .docker
    chmod 0750 .docker
)

# Docker needs systemd cgroup
sed -i -e 's,^[ \t]*if .*mountinfo .*/sys/fs/cgroup/openrc,\tfor name in openrc systemd; do\n&,' \
    -e 's,\(/sys/fs/cgroup/\)openrc,\1\$name,' \
    -e 's/\(-o none,.*name *= *\)openrc/\1\$name/' -e 's/^\([ \t]*\)openrc /\1\$name /' \
    -e '/^[ \t]*return 0/{s//\tdone\n&/;:p;n;bp;}' /mnt/etc/init.d/cgroups

# Configure VMware service
#sed -i 's/^# *\(vm_drag_and_drop\) *=.*/\1="yes"/' /mnt/etc/conf.d/open-vm-tools
printf 'vmhgfs-fuse\t/mnt/hgfs\tfuse\tallow_other\t0 0\n' >> /mnt/etc/fstab
#sed -i 's/^# *\(extra_net_fs_list *= *"[^"]*\)/\1 fuse.vmhgfs-fuse/' /mnt/etc/rc.conf
mkdir -p /mnt/mnt/hgfs
for drv in c d; do ln -sf mnt/hgfs "/mnt/$drv"; done
sed -i 's,umount -a -O.*,& 2>/dev/null || true,' /mnt/etc/init.d/netmount


umount /mnt
poweroff
