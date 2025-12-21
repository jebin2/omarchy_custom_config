#!/bin/bash

echo "Available partitions:"
lsblk -f | grep -E "sda|sdb|sdc"

read -p "Do you want to (m)ount or (u)nmount? " action

if [[ "$action" == "m" ]]; then
  # --- Mount workflow ---
  read -p "Enter partition to mount (e.g., sda2): " part
  device="/dev/$part"

  echo "Running ntfsfix on $device..."
  sudo ntfsfix "$device"

  label=$(lsblk -no LABEL "$device" | tr -d ' ')
  if [ -z "$label" ]; then
    label="newvolume"
  fi

  mount_point="/mnt/$label"
  sudo mkdir -p "$mount_point"

  echo "Mounting $device to $mount_point..."
  sudo mount -t ntfs-3g "$device" "$mount_point" &&
    echo "✅ Mounted at $mount_point" ||
    echo "❌ Failed to mount"

elif [[ "$action" == "u" ]]; then
  # --- Unmount workflow ---
  echo "Currently mounted NTFS partitions:"
  mount | grep ntfs

  read -p "Enter mount point or device to unmount (e.g., /mnt/newvolume or /dev/sda2): " target
  echo "Unmounting $target..."
  sudo umount "$target" &&
    echo "✅ Unmounted $target" ||
    echo "❌ Failed to unmount"

else
  echo "Invalid choice. Use 'm' for mount or 'u' for unmount."
fi
