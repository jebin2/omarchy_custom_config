sudo nano /etc/kernelstub/configuration
sudo kernelstub -a "nvidia.NVreg_EnableGpuFirmware=0 pcie_aspm=off"

#sudo nvidia-smi -pm 1

# 1. Purge all existing Nvidia traces
sudo apt purge ~nnvidia

# 2. Clean up any leftovers
sudo apt autoremove && sudo apt autoclean

# 3. Install the official System76 Nvidia driver
sudo apt install system76-driver-nvidia

# 4. Reboot
reboot
