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
│        Virtual Machine Cleanup v1.0         │
│                                             │
│     Destroy and Undefine VMs Automatically  │
│                                             │
└─────────────────────────────────────────────┘
"

# List of VMs to process
VMS=("master-1" "master-2" "master-3" "worker-1" "worker-2" "worker-3" "nginx-0")

print_color "1;36" "VMs to be processed:"
for vm in "${VMS[@]}"; do
    echo "- $vm"
done

# Function to process a VM
process_vm() {
    local vm=$1
    print_color "1;33" "\nProcessing VM: $vm"
    
    print_color "1;35" "Destroying VM..."
    if virsh destroy "$vm"; then
        print_color "1;32" "✓ VM $vm destroyed successfully"
    else
        print_color "1;31" "! Failed to destroy VM $vm (it may already be off)"
    fi
    
    print_color "1;35" "Undefining VM..."
    if virsh undefine "$vm" --remove-all-storage; then
        print_color "1;32" "✓ VM $vm undefined successfully"
    else
        print_color "1;31" "! Failed to undefine VM $vm"
    fi
}

# Main execution
for vm in "${VMS[@]}"; do
    process_vm "$vm"
done

# Final banner
print_color "1;34" "
┌─────────────────────────────────────────────┐
│                                             │
│        VM Cleanup Process Complete          │
│                                             │
└─────────────────────────────────────────────┘
"

print_color "1;32" "All specified VMs have been processed."
print_color "1;33" "NOTE: If any errors occurred, please check the output above."
print_color "1;36" "To verify, you can run: virsh list --all"

