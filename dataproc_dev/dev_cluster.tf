# -----------------------------------------------------------
# Dataproc 開發叢集 (Daily Development Cluster)
# 用途: Jupyter 互動式開發,當日用完即關閉
# 成本優化: 最小配置 + 自動關閉 + 可搶佔 Worker
# -----------------------------------------------------------
# 指定provider版本
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.48.0"
    }
  }
}

# 設定Provider
provider "google"{
    project=var.gcp_project_id
    region=var.gcp_region
}

resource "google_dataproc_cluster" "ubike_dev_cluster" {
  name    = "${var.gcp_project_id}-dev-jupyter-cluster"
  project = var.gcp_project_id
  region  = var.gcp_region


  cluster_config {
    staging_bucket = var.staging_bucket_name

    # 啟用 Component Gateway - 通過瀏覽器安全訪問 Jupyter
    endpoint_config {
      enable_http_port_access = true
    }



    # 自動刪除設定 - 閒置 2 小時後自動刪除(防止忘記關閉)
    lifecycle_config {
      idle_delete_ttl = "7200s"
    }

    # 節點配置
    gce_cluster_config {
      service_account = var.service_account_email
      
      # 不需要外部 IP(透過 Component Gateway 訪問)
      internal_ip_only = true
      
      # 標籤用於成本追蹤
      tags = ["dataproc-dev", "jupyter"]
    }

    # Master 節點 (運行 Jupyter + Spark Driver)
    # 建議: e2-standard-2 足夠開發使用
    master_config {
      num_instances = 1
      machine_type  = "e2-standard-2"  # 2 vCPU, 8 GB RAM
      
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 100  # 減少到 100GB(開發用途足夠)
      }
    }

    # Worker 節點 (運行 Spark Executors)
    # 建議: 開發時用 1-2 個 worker 即可
    worker_config {
      num_instances = 2  # 最小配置
      machine_type  = "e2-standard-2"
      
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 100
      }
    }

    # 可搶佔 Worker - 進一步降低成本(約省 60-80%)
    # 開發環境可以接受偶爾被搶佔,生產環境不建議
    preemptible_worker_config {
      num_instances = 1  # 額外 1 個可搶佔 worker
      
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 100
      }
    }

    # 軟體配置
    software_config {
      image_version = "2.2-debian12"  # 使用較新版本
      
      optional_components = [
        "JUPYTER"
      ]

      # Spark 記憶體配置(開發用途,保守配置)
      override_properties = {
        "spark:spark.driver.memory"    = "3g"
        "spark:spark.executor.memory"  = "3g"
        "spark:spark.executor.cores"   = "2"
        "spark:spark.executor.instances" = "2"
      }
    }
  }
}

# Output - 顯示 Jupyter 訪問連結
output "jupyter_url" {
  description = "Jupyter Notebook 訪問 URL"
  value       = "https://console.cloud.google.com/dataproc/clusters/${google_dataproc_cluster.ubike_dev_cluster.name}/web-interfaces?project=${var.gcp_project_id}&region=${var.gcp_region}"
}

output "cluster_name" {
  description = "Dataproc 叢集名稱"
  value       = google_dataproc_cluster.ubike_dev_cluster.name
}