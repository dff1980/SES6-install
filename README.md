# SUSE Enterprise Storage 5 2019 PoC

This project is PoC installation SUSE Enterprise Storage 5.

Using version:
- SES 5
- SLES 12 SP3

This document currently in development state. Any comments and additions are welcome.
If you need some additional information about it please contact with Pavel Zhukov (pavel.zhukov@suse.com).


###### Disclaimer
###### _At the moment, no one is responsible if you try to use the information below for productive installations or commercial purposes._

## PoC Landscape
PoC can be deployed in any virtualization environment or on hardware servers.
Currently, PoC hosted on VMware VSphere.

## Requarments

### Tech Specs
- 1 dedicated infrastructure server ( DNS, DHCP, PXE, NTP, NAT, SMT, TFTP, SES admin)
    
    16GB RAM
    
    1 x HDD - 200GB
    
    1 LAN adapter
    
    1 WAN adapter

- 4 x SES Servers
  
   16GB RAM
  
   1 x HDD (System) - 100GB
  
   3 x HDD (Data) - 20 GB
  
   1 LAN

### Network Architecture
All server connect to LAN network (isolate from another world). In current state - 192.168.15.0/24.
Infrastructure server also connects to WAN.

## Instalation Procedure
### Install infrastructure server
#### 1. Install SLES12 SP3
#### 2. Add FQDN to /etc/hosts
Hostname=admin.ses5.suse.ru

Exaple change:
_192.168.15.254 admin_
to
_192.168.15.254 admin.ses5.suse.ru admin_
or (for eth1 LAN interface)
```bash
echo "$(ip a | grep -A1 eth1 | grep inet | sed 's/\s*inet\s*\(.*\)\/..\sbrd.*/\1/') $(hostname).ses5.suse.ru $(hostname)" >> /etc/hosts
```
#### 3. Configure NTP.
```bash
yast2 ntp-client
```
#### 4. Configure Firewall.
```bash
yast2 firewall
```
#### 5. Configure SMT.
Execute SMT configuration wizard. During the server certificate setup, all possible DNS for this server has been added (SMT FQDN, etc).
Add repositories to replication.
```bash
sudo zypper in -t pattern smt

for REPO in SLES12-SP3-{Pool,Updates} SUSE-Enterprise-Storage-5-{Pool,Updates}; do
  smt-repos $REPO sle-12-x86_64 -e
done

smt-mirror -L /var/log/smt/smt-mirror.log
```
Download next distro:
- SLE-12-SP3-Server-DVD-x86_64-GM-DVD1.iso

Create install repositories:

```bash
mkdir -p /srv/www/htdocs/repo/SUSE/Install/SLE-SERVER/12-SP3

mkdir -p /srv/tftpboot/sle12sp3

mount SLE-12-SP3-Server-DVD-x86_64-GM-DVD1.iso /mnt
rsync -avP /mnt/ /srv/www/htdocs/repo/SUSE/Install/SLE-SERVER/12-SP3/x86_64/
cp /mnt/boot/x86_64/loader/{linux,initrd} /srv/tftpboot/sle12sp3/
umount /mnt

```

### 6. Configure DNS & DHCP
```bash
zypper in -t pattern dhcp_dns_server
```

#### Configure DHCP
Put file [/etc/dhcpd.conf](data/etc/dhcpd.conf) to the server.

Set interface in /etc/sysconfig/dhcpd
```
DHCPD_INTERFACE="eth1"
```

start dhcp service.
```bash
systemctl enable dhcpd.service
systemctl start dhcpd.service
```

#### Configure DNS

Configure zone for PoC and all nodes.

Put file zone [/var/lib/named/master/ses5.suse.ru](data/var/lib/named/master/ses5.suse.ru) to the server.
Put file zone [/var/lib/named/master/20.168.192.in-addr.arpa](data/var/lib/named/master/20.168.192.in-addr.arpa) to the server.

Add description in /etc/named.conf

```
zone "ses5.suse.ru" in {
        allow-transfer { any; };
        file "master/ses5.suse.ru";
        type master;
};
zone "15.168.192.in-addr.arpa" in {
        file "master/15.168.192.in-addr.arpa";
        type master;
};        
```

```bash
systemctl enable named.service
systemctl start named.service
```

### 7. Configure TFTP
```bash
zypper in -y tftp
```
```bash
yast2 tftp-server
```
or add to autostart xntpd and configure tfpfd

Copy [/srv/tftpboot/*](data/srv/tftpboot/) to server.

## Install SES
### 1. Stop firewall at Infrastructure server at installing SES time.
```bash
systemctl stop SuSEfirewall2
```
### 2. Configure AutoYast
Put [/srv/www/htdocs/autoyast/autoinst_osd.xml](data/srv/www/htdocs/autoyast/autoinst_osd.xml) to the server.

get AutoYast Fingerprint

openssl x509 -noout -fingerprint -sha256 -inform pem -in /srv/www/htdocs/smt.crt

Change /srv/www/htdocs/autoyast/autoinst_osd.xml Add

to <suse_register>

<reg_server>https://smt.sdh.suse.ru</reg_server> <reg_server_cert_fingerprint_type>SHA256</reg_server_cert_fingerprint_type> 

<reg_server_cert_fingerprint>YOUR SMT FINGERPRINT</reg_server_cert_fingerprint>

### 3. Install SES Nodes
Boot all SES Node from PXE and chose "Install OSD Node" from PXE boot menu.

### 4. Configure SES
1. Start [data/ses-install/start.sh](data/ses-install/start.sh) at infrastructure server.
2. Run
```bash
salt-run state.orch ceph.stage.0
```
3. Run
```bash
salt-run state.orch ceph.stage.1
```
4. Put [/srv/pillar/ceph/proposals/policy.cfg](data/srv/pillar/ceph/proposals/policy.cfg) to server.
5. Run
```bash
salt-run state.orch ceph.stage.2
```
After the command finishes, you can view the pillar data for minions by running:
```bash
salt '*' pillar.items
```
6. Run
```bash
salt-run state.orch ceph.stage.3
```
If it fails, you need to fix the issue and run the previous stages again. After the command succeeds, run the following to check the status:
```bash
ceph -s
```
7. Run
```bash
salt-run state.orch ceph.stage.4
```

### 5. Start firewall at Infrastructure Server
```bash
systemctl start SuSEfirewall2
```

## Configure SUSE CaaSP and SES integration

1. Add rbd pool (you can use OpenAttic Web interface at infrastructure node)

2. Retrieve the Ceph admin secret. Get the key value from the file /etc/ceph/ceph.client.admin.keyring.

On the master node apply the configuration that includes the Ceph secret by using kubectl apply. Replace CEPH_SECRET with your Ceph secret.
```bash
tux > kubectl apply -f - << *EOF*
apiVersion: v1
kind: Secret
metadata:
  name: ceph-secret
type: "kubernetes.io/rbd"
data:
  key: "$(echo CEPH_SECRET | base64)"
*EOF*
```

3. Add Storage Class
```bash
kubectl create -f rbd_storage.yaml
```
## OpenStack Integration (new in SES 5.5!)
DeepSea now includes an openstack.integrate runner which will create the necessary storage pools and cephx keys for use by OpenStack Glance, Cinder, and Nova. It also returns a block of configuration data that can be used to subsequently configure OpenStack. To learn more about this feature, run the following command on the administration node: salt-run openstack.integrate -d

## Test Enviroment
```bash
ceph status
rbd list
rbd create -s 10 rbd_test
rbd info rbd_test
rbd rm rbd_test
```

## Appendix 
### SUSE Enterprise Storage 5 Documentation
https://www.suse.com/documentation/suse-enterprise-storage-5/

### SUSE CaaS Platform 3 Documentation
https://www.suse.com/documentation/suse-caasp-3/index.html

## Appendix A
To prevent some error(warning) message specify ipv6 for hostname

To pretty out ussing
```bash
salt-run state.event pretty=True
```
or
```bash
deepsea monitor
```
#### ceph-authtool
To create a new keyring containing a key for client.foo:

ceph-authtool -C -n client.foo --gen-key keyring
To associate some capabilities with the key (namely, the ability to mount a Ceph filesystem):

ceph-authtool -n client.foo --cap mds 'allow' --cap osd 'allow rw pool=data' --cap mon 'allow r' keyring
To display the contents of the keyring:

ceph-authtool -l keyring
When mount a Ceph file system, you can grab the appropriately encoded secret key with:

mount -t ceph serverhost:/ mountpoint -o name=foo,secret=`ceph-authtool -p -n client.foo keyring`
