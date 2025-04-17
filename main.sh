#!/bin/bash

# Function to print colored text
print_color() {
    local color=$1
    local text=$2
    echo -e "\e[${color}m${text}\e[0m"
}

# Banner
print_color "1;34" "
┌─────────────────────────────────────────────┐
│                                             │
│           KVM Setup Script v1.0             │
│                                             │
│        Automated VM Deployment Tool         │
│                                             │
└─────────────────────────────────────────────┘
"

# Constants
UBUNTU_IMAGE_URL="https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
IMAGE_NAME="ubuntu-24.04-server-cloudimg-amd64.img"
BRIDGE_NAME="bridge0"
VM_USER="rajkamal"
USER_PASSWORD="kamal2002"
SSH_KEY_PATH="/home/rajkamal/k8s-setup/key.pub"
####STORAGE_PATH="/var/lib/libvirt/images/k8s"
STORAGE_PATH="/home/VM-Disk/k8s"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    print_color "1;31" "Error: This script must be run as root."
    exit 1
fi

# Print script information
print_color "1;36" "Script Information:"
echo "- Debian Image: $UBUNTU_IMAGE_URL"
echo "- Bridge: $BRIDGE_NAME"
echo "- VM User: $VM_USER"
echo "- Storage Path: $STORAGE_PATH"

# Removing old images
#print_color "1;33" "\nCleaning up old images..."
#rm -rf $STORAGE_PATH/master-*
#rm -rf $STORAGE_PATH/worker-*

# Ensure necessary commands are available
print_color "1;33" "\nChecking required commands..."
for cmd in wget qemu-img virt-install openssl; do
    if ! command -v $cmd &> /dev/null; then
        print_color "1;31" "Error: $cmd is not installed."
        exit 1
    fi
    print_color "1;32" "✓ $cmd"
done

# Ensure storage directory exists
print_color "1;33" "\nSetting up storage directory..."
mkdir -p $STORAGE_PATH || { print_color "1;31" "Error: Failed to create storage directory."; exit 1; }
##chmod -R 770 $STORAGE_PATH
print_color "1;32" "Storage directory set up successfully."

# Download Ubuntu cloud image if not exists
print_color "1;33" "\nChecking for Debian cloud image..."
if [ ! -f "$STORAGE_PATH/$IMAGE_NAME" ]; then
    print_color "1;34" "Downloading Ubuntu cloud image..."
    wget $UBUNTU_IMAGE_URL -O $STORAGE_PATH/$IMAGE_NAME || { print_color "1;31" "Error: Failed to download image."; exit 1; }
    ##chown libvirt-qemu:kvm "$STORAGE_PATH/$IMAGE_NAME"
    ##chmod 660 "$STORAGE_PATH/$IMAGE_NAME"
    print_color "1;32" "Ubuntu cloud image downloaded successfully."
else
    print_color "1;32" "Ubuntu cloud image already exists."
fi

# Function to create a VM
create_vm() {
    local VM_TYPE=$1
    local VM_NUMBER=$2
    local VM_CPU=$3
    local VM_RAM=$4
    local VM_IP=$5
    local VM_NAME="${VM_TYPE}-${VM_NUMBER}"

    print_color "1;34" "\nCreating VM: $VM_NAME"
    print_color "1;36" "- Type: $VM_TYPE"
    print_color "1;36" "- Number: $VM_NUMBER"
    print_color "1;36" "- CPU: $VM_CPU"
    print_color "1;36" "- RAM: $VM_RAM MB"
    print_color "1;36" "- IP: $VM_IP"

    # Create a copy of the base image
    qemu-img create -f qcow2 -F qcow2 -b "$STORAGE_PATH/$IMAGE_NAME" "${STORAGE_PATH}/${VM_NAME}.qcow2" 20G
    ##chown libvirt-qemu:kvm "${STORAGE_PATH}/${VM_NAME}.qcow2"
    ##chmod 660 "${STORAGE_PATH}/${VM_NAME}.qcow2"

    # Create cloud-init config with static IP
    cat > "${VM_NAME}-cloud-init.yml" <<EOF
#cloud-config
hostname: ${VM_NAME}
users:
  - name: ${VM_USER}
    lock_passwd: false
    passwd: $(openssl passwd -1 -salt SaltSalt "${USER_PASSWORD}")
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "$SSH_KEY_PATH")

# Disable cloud-init network configuration
network:
  config: disabled

write_files:
  - path: /etc/netplan/01-netcfg.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          enp1s0:
            dhcp4: false
            dhcp6: false
            addresses: [${VM_IP}/24]
            routes:
              - to: default
                via: 192.168.1.1
            nameservers:
              addresses: [8.8.8.8, 8.8.4.4]

runcmd:
  - apt update
  - apt install -y netplan.io
  - if [ -f /etc/netplan/50-cloud-init.yaml ]; then rm /etc/netplan/50-cloud-init.yaml; fi
  - chmod 644 /etc/netplan/01-netcfg.yaml
  - netplan apply
  - mkdir -p /home/rajkamal/.ssh/
EOF

    # Create the VM
    virt-install --name "${VM_NAME}" \
                 --virt-type kvm \
                 --memory "${VM_RAM}" \
                 --vcpus "${VM_CPU}" \
                 --disk path="${STORAGE_PATH}/${VM_NAME}.qcow2",format=qcow2,size=20 \
                 --network bridge="${BRIDGE_NAME}",model=virtio \
                 --os-variant debian11 \
                 --graphics none \
                 --noautoconsole \
                 --import \
                 --cloud-init user-data="${VM_NAME}-cloud-init.yml"

    # Clean up
    rm "${VM_NAME}-cloud-init.yml"
    print_color "1;32" "VM $VM_NAME created successfully."
}

# Create VMs
print_color "1;33" "\nCreating Virtual Machines..."
create_vm "master" 1 4 8192 "192.168.1.60"
create_vm "master" 2 4 8192 "192.168.1.64"
create_vm "worker" 1 2 4096 "192.168.1.61"
create_vm "worker" 2 2 4096 "192.168.1.62"
create_vm "worker" 3 2 4096 "192.168.1.63"

print_color "1;32" "\nAll VMs created successfully."
print_color "1;33" "Please note the IP addresses and update your DNS or /etc/hosts file accordingly."

# Final banner
print_color "1;34" "
┌─────────────────────────────────────────────┐
│                                             │
│        KVM Setup Completed Successfully     │
│                                             │
└─────────────────────────────────────────────┘
"
