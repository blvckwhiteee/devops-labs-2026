output "worker_ip" {
  description = "IP address of the worker VM (nginx + webapp)"
  value       = var.worker_ip
}

output "db_ip" {
  description = "IP address of the db VM (MariaDB)"
  value       = var.db_ip
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key for the ansible user"
  value       = local_sensitive_file.private_key.filename
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "connect_worker" {
  description = "SSH command to connect to worker as ansible"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ansible@${var.worker_ip}"
}

output "connect_db" {
  description = "SSH command to connect to db as ansible"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ansible@${var.db_ip}"
}
