#!/bin/bash


#update ubuntu
apt-get --yes update && apt-get --yes upgrade && apt-get --yes dist-upgrade

export DEBIAN_FRONTEND=noninteractive
apt-get --yes install libnss-ldap libpam-ldap ldap-utils nslcd
unset DEBIAN_FRONTEND


git clone https://github.com/ashand01/nti310.git /tmp/NTI310


#adjust /etc/ldap/ldap.conf file for ip address and fqdn
sed -i "s,#URI\tldap:\/\/ldap.example.com ldap:\/\/ldap-master.example.com:666,URI\tldaps:\/\/10.138.0.4,g" /etc/ldap/ldap.conf
sed -i 's/#BASE\tdc=example,dc=com/BASE\tdc=ali,dc=local/g' /etc/ldap/ldap.conf
sed -i -e '$aTLS_REQCERT allow' /etc/ldap/ldap.conf

cp /tmp/NTI310/config_files/ldap.conf /etc/ldap.conf
sed -i "s,uri ldaps:\/\/NEEDTOADDIP\/,uri ldaps:\/\/10.138.0.4\/,g" /etc/ldap.conf
cp /tmp/NTI310/config_files/nslcd.conf /etc/nslcd.conf
sed -i "s,uri ldaps:\/\/NEEDTOADDIP\/,uri ldaps:\/\/10.138.0.4\/,g" /etc/nslcd.conf

sed -i 's,passwd:         compat,passwd:         ldap compat,g' /etc/nsswitch.conf
sed -i 's,group:          compat,group:          ldap compat,g' /etc/nsswitch.conf
sed -i 's,shadow:         compat,shadow:         ldap compat,g' /etc/nsswitch.conf


sed -i '$ a\session required    pam_mkhomedir.so skel=/etc/skel umask=0022' /etc/pam.d/common-session

/etc/init.d/nscd restart

sed -i 's,PasswordAuthentication no,#PasswordAuthentication no,g' /etc/ssh/sshd_config

sed -i 's,ChallengeResponseAuthentication no,#ChallengeResponseAuthentication no,g' /etc/ssh/sshd_config

systemctl restart sshd.service

#login as ldap user on the ubuntu-desktop!
#command from terminal: ssh <username>@<ubuntuIPaddress>
#enter user password defined in phpldapadmin

#this script installs the ubuntu client side of nfs and mounts the volumes -- run as root

#install the nfs client packages
apt-get -y install nfs-common nfs-kernel-server
service nfs-kernel-server start

#create mount directories
mkdir -p /mnt/nfs/home
mkdir -p /mnt/nfs/var/dev
mkdir -p /mnt/nfs/var/config

#start the mapping service
service nfs-idmapd start

#mount the volumes
mount -v -t nfs nfs-server:/home /mnt/nfs/home
mount -v -t nfs nfs-server:/var/dev /mnt/nfs/var/dev
mount -v -t nfs nfs-server:/var/config /mnt/nfs/var/config

#make changes mounting the nfs volumes permanent by editing fstab
echo "nfs-server:/home /mnt/nfs/home   nfs     defaults 0 0" >> /etc/fstab
echo "nfs-server:/var/dev /mnt/nfs/var/dev    nfs     defaults 0 0" >> /etc/fstab
echo "nfs-server:/var/config /mnt/nfs/var/config    nfs     defaults 0 0" >> /etc/fstab

#install tree to verify mount
apt-get -y install tree

#verify the mount
df -h
tree /mnt

#rsyslog client-side configuration -- run as root
#must be run on each rsyslog client

ip=$(gcloud compute instances list | grep rsyslog-server | awk '{print $4}')

echo "*.info;mail.none;authpriv.none;cron.none    @$ip" >> /etc/rsyslog.conf


sudo service rsyslog restart        

systemctl restart sshd
systemctl restart nslcd
systemctl restart systemd-logind.service
