# Ansible Inventory

`hosts.ini` is generated automatically by Terraform when you run `terraform apply`
inside the `terraform/` directory. It will be placed here with the actual IPs of
the two VMs.

## Manual static inventory (grader / not your machine)

If you are verifying this lab on a different machine, create `hosts.ini` manually:

```ini
[workers]
worker01 ansible_host=<WORKER_VM_IP>

[db]
db01 ansible_host=<DB_VM_IP>

[all:vars]
ansible_user=ansible
ansible_ssh_private_key_file=<PATH_TO_ANSIBLE_PRIVATE_KEY>
ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

Replace `<WORKER_VM_IP>`, `<DB_VM_IP>` with the actual IPs shown in VirtualBox,
and `<PATH_TO_ANSIBLE_PRIVATE_KEY>` with the path to the private key added to
the `ansible` user's `authorized_keys` during VM provisioning (cloud-init).
