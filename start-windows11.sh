#!/bin/bash

VM_NAME="win11"
URI="qemu:///system"

# Start the VM
/usr/bin/virsh -c $URI start $VM_NAME

# Wait until the VM state is "running"
# The 'grep -q' is a quiet search. The loop continues until it finds the word "running".
while ! /usr/bin/virsh -c $URI domstate $VM_NAME | grep -q "running"; do
  sleep 1 # Wait 1 second between checks to not overload the system
done

# Now that the VM is confirmed to be running, launch the viewer
/usr/bin/virt-viewer -c $URI $VM_NAME &
