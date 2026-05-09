variable "base_ova_path" {
  description = "Absolute path to Ubuntu 24.04 LTS cloud-image OVA (noble-server-cloudimg-amd64.ova)"
  type        = string
}

variable "vms_dir" {
  description = "Directory where VirtualBox stores VM disk files"
  type        = string
  default     = "C:/VirtualBox-VMs"
}

variable "hostonlyif_name" {
  description = "VirtualBox host-only adapter name (run: VBoxManage list hostonlyifs)"
  type        = string
  default     = "VirtualBox Host-Only Ethernet Adapter"
}

variable "worker_memory" {
  description = "RAM for worker VM, MB"
  type        = number
  default     = 2048
}

variable "worker_cpus" {
  description = "CPU count for worker VM"
  type        = number
  default     = 2
}

variable "db_memory" {
  description = "RAM for db VM, MB"
  type        = number
  default     = 1024
}

variable "db_cpus" {
  description = "CPU count for db VM"
  type        = number
  default     = 1
}

variable "worker_ip" {
  description = "Static IP for worker VM on host-only network"
  type        = string
  default     = "192.168.56.10"
}

variable "db_ip" {
  description = "Static IP for db VM on host-only network"
  type        = string
  default     = "192.168.56.11"
}

variable "network_gateway" {
  description = "Gateway IP of the host-only network"
  type        = string
  default     = "192.168.56.1"
}
