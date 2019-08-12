#!/bin/bash
if [ -z "$1" ]
then
echo "Using: $0 {First Device Name exaple: sdb} [Second Device Name] ... [X Device Name]"
exit 0
fi

for device in $@
do
  #Wipe the beginning of each partition (as root)
  for partition in /dev/${device}[0-9]*
  do
    dd if=/dev/zero of=$partition bs=4096 count=1 oflag=direct
  done

  #Wipe the beginning of the drive:
  dd if=/dev/zero of=/dev/${device} bs=512 count=34 oflag=direct
  dd if=/dev/zero of=/dev/${device} bs=512 count=33 seek=$((`blockdev --getsz /dev/sdX` - 33)) oflag=direct

  #Create a new GPT partition table

  sgdisk -Z --clear -g /dev/${device}
done

