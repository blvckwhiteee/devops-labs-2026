resource "tls_private_key" "ansible" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ansible.private_key_openssh
  filename        = "${path.root}/../.ssh/id_ed25519_lab4"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ansible.public_key_openssh
  filename = "${path.root}/../.ssh/id_ed25519_lab4.pub"
}

locals {
  cloud_init_dir = "${path.module}/.cloud-init"

  user_data_worker = templatefile("${path.module}/templates/user-data.yaml.tpl", {
    hostname   = "worker01"
    static_ip  = var.worker_ip
    gateway    = var.network_gateway
    ssh_pubkey = trimspace(tls_private_key.ansible.public_key_openssh)
  })

  user_data_db = templatefile("${path.module}/templates/user-data.yaml.tpl", {
    hostname   = "db01"
    static_ip  = var.db_ip
    gateway    = var.network_gateway
    ssh_pubkey = trimspace(tls_private_key.ansible.public_key_openssh)
  })

  meta_data_worker = templatefile("${path.module}/templates/meta-data.yaml.tpl", {
    hostname = "worker01"
  })

  meta_data_db = templatefile("${path.module}/templates/meta-data.yaml.tpl", {
    hostname = "db01"
  })
}

resource "local_file" "user_data_worker" {
  content  = local.user_data_worker
  filename = "${local.cloud_init_dir}/worker/user-data"
}

resource "local_file" "meta_data_worker" {
  content  = local.meta_data_worker
  filename = "${local.cloud_init_dir}/worker/meta-data"
}

resource "local_file" "user_data_db" {
  content  = local.user_data_db
  filename = "${local.cloud_init_dir}/db/user-data"
}

resource "local_file" "meta_data_db" {
  content  = local.meta_data_db
  filename = "${local.cloud_init_dir}/db/meta-data"
}

resource "null_resource" "iso_worker" {
  triggers = {
    user_data = local.user_data_worker
    meta_data = local.meta_data_worker
  }

  depends_on = [local_file.user_data_worker, local_file.meta_data_worker]

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      ${path.module}/scripts/make-iso.ps1 `
        -SourceDir  '${path.module}/.cloud-init/worker' `
        -OutputIsoPath '${path.module}/.cloud-init/worker.iso'
    PS
  }
}

resource "null_resource" "iso_db" {
  triggers = {
    user_data = local.user_data_db
    meta_data = local.meta_data_db
  }

  depends_on = [local_file.user_data_db, local_file.meta_data_db]

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      ${path.module}/scripts/make-iso.ps1 `
        -SourceDir  '${path.module}/.cloud-init/db' `
        -OutputIsoPath '${path.module}/.cloud-init/db.iso'
    PS
  }
}

resource "null_resource" "vm_worker" {
  triggers = {
    ova          = var.base_ova_path
    memory       = var.worker_memory
    cpus         = var.worker_cpus
    user_data_id = null_resource.iso_worker.id
  }

  depends_on = [null_resource.iso_worker]

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      ${path.module}/scripts/create-vm.ps1 `
        -VmName     'worker01' `
        -OvaPath    '${var.base_ova_path}' `
        -BaseFolder '${var.vms_dir}' `
        -IsoPath    '${path.module}/.cloud-init/worker.iso' `
        -HostOnlyIf '${var.hostonlyif_name}' `
        -Memory     ${var.worker_memory} `
        -Cpus       ${var.worker_cpus}
    PS
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = "${path.module}/scripts/wait-for-ssh.ps1 -Host '${var.worker_ip}'"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = "${path.module}/scripts/destroy-vm.ps1 -VmName 'worker01'"
  }
}

resource "null_resource" "vm_db" {
  triggers = {
    ova          = var.base_ova_path
    memory       = var.db_memory
    cpus         = var.db_cpus
    user_data_id = null_resource.iso_db.id
  }

  depends_on = [null_resource.iso_db]

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      ${path.module}/scripts/create-vm.ps1 `
        -VmName     'db01' `
        -OvaPath    '${var.base_ova_path}' `
        -BaseFolder '${var.vms_dir}' `
        -IsoPath    '${path.module}/.cloud-init/db.iso' `
        -HostOnlyIf '${var.hostonlyif_name}' `
        -Memory     ${var.db_memory} `
        -Cpus       ${var.db_cpus}
    PS
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = "${path.module}/scripts/wait-for-ssh.ps1 -Host '${var.db_ip}'"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = "${path.module}/scripts/destroy-vm.ps1 -VmName 'db01'"
  }
}

resource "local_file" "ansible_inventory" {
  depends_on = [null_resource.vm_worker, null_resource.vm_db]
  filename   = "${path.root}/../ansible/inventory/hosts.ini"
  content    = <<-INI
    [workers]
    worker01 ansible_host=${var.worker_ip}

    [db]
    db01 ansible_host=${var.db_ip}

    [all:vars]
    ansible_user=ansible
    ansible_ssh_private_key_file=${path.root}/../.ssh/id_ed25519_lab4
    ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  INI
}
