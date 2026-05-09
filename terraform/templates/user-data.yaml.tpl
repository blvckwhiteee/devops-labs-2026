#cloud-config
hostname: ${hostname}
manage_etc_hosts: true

users:
  - name: ansible
    groups: [sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_pubkey}

packages:
  - python3
  - python3-apt
  - curl

package_update: true

write_files:
  - path: /etc/netplan/60-lab4-static.yaml
    permissions: "0600"
    content: |
      network:
        version: 2
        ethernets:
          enp0s8:
            dhcp4: false
            addresses:
              - ${static_ip}/24
            routes:
              - to: default
                via: ${gateway}
                metric: 200

runcmd:
  - netplan apply
  - systemctl enable --now qemu-guest-agent || true
