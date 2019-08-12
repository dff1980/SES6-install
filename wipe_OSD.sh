for node in 1 2 3 4
 do
   scp wipe_disk.sh osd-0$node:/tmp/
   ssh osd-0$node 'bash /tmp/wipe_disk.sh sdb sdc sdd'
   ssh osd-0$node 'rm /tmp/wipe_disk.sh'
   ssh osd-0$node 'reboot'
 done
