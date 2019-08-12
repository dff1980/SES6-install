#!/bin/bash
zypper in -y salt-master salt-minion
systemctl enable salt-master salt-minion
echo "master: ses-admin.ses6.suse.ru" > /etc/salt/minion.d/minion.conf
sleep 15
systemctl start salt-master
systemctl start salt-minion
salt-key
salt-key -A -y
sleep 15
salt '*' test.ping
salt '*' cmd.run date
salt '*' grains.append deepsea default
zypper in -y deepsea
