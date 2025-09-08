
# 布署 VM
resource "google_compute_instance" "airflow_vm" {
  name         = "${var.gcp_project_id}-airflow-vm"
  machine_type = var.gcp_machine_type
  zone         = "${var.gcp_region}-b"

  # 加入網路標籤，讓防火牆規則可以應用到這個 VM。
  tags = ["airflow-vm"]

  # 開機使用的作業軟體
  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250805"
      size=var.gcp_disk_size_gb
    }
  }

  # 網路介面
  network_interface {
    # 連接到你的 Google Cloud 專案中名為 "default" 的虛擬網路
    network = "default"

    # 分配一個公用 IP，以便從網際網路輕鬆進行 SSH 連線。
    access_config {
      // 臨時 IP
    }
  }

  # 賦予 VM 權限，讓它可以像服務帳號一樣運作。
  service_account{
    email=google_service_account.airflow_service_account.email
    scopes=[
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # 啟動腳本會在 VM 首次建立時自動運行。
  # 這個腳本會安裝並配置 Docker 和 Docker Compose。
  metadata_startup_script = file("startup-script.sh")
}


# 防火牆規則，允許流量進入我們的 VM。
# 我們將開啟 port 22 給 SSH，以及 port 8080 給 Airflow 的 UI 介面。
resource "google_compute_firewall" "airflow_firewall"{
  name="${var.gcp_project_id}-airflow-firewall-rule"
  network="default"

  allow{
    protocol="tcp"
    ports=["22","8080"]
  }

  # 此規則將會應用到所有帶有 "airflow-vm" 標籤的 VM。
  target_tags=["airflow-vm"]

  source_ranges=[var.allowed_ip]

}