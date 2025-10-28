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

# 布署google_bigquery_dataset 
resource "google_bigquery_dataset" "data_warehouse"{
    dataset_id="${var.bigquery_dataset_id}_data_warehouse"
    description = "Dataset for storing transformed data models from dbt."
    location=var.gcp_region
}

# 部署原始資料集 (Staging Dataset)
# 用於存放從 GCS 載入的原始資料。
resource "google_bigquery_dataset" "staging_dataset" {
  dataset_id  = "${var.bigquery_dataset_id}_staging"
  description = "Dataset for raw data loaded from GCS. It serves as the source for dbt."
  location    = var.gcp_region
  default_table_expiration_ms = var.staging_table_expiration_ms
}

# 布署 GCS_bucket
resource "google_storage_bucket" "data_lake_bucket"{
    name="${var.gcp_project_id}-${var.gcs_bucket_name_suffix}"
    location=var.gcp_region
    uniform_bucket_level_access = true
    lifecycle_rule {
        condition {
            age = 1
        }
        action {
            type = "AbortIncompleteMultipartUpload"
        }
    }
}

# 存放 PySpark 腳本的資料夾 (供 Dataproc 執行)
# 路徑: gs://<bucket_name>/scripts/
resource "google_storage_bucket_object" "scripts_folder" { # <-- (A) 新增的資源類型
  # 參考您已定義的 GCS 儲存桶 (假設名稱為 data_lake_bucket)
  bucket = google_storage_bucket.data_lake_bucket.name 
  name   = "scripts/" # <-- (B) 透過這個屬性名稱和斜線尾巴建立資料夾
  content_type = "application/x-directory"
  content = " "
}

# 啟用 Dataproc 服務
resource "google_project_service" "dataproc_api" {
    project = var.gcp_project_id
    service = "dataproc.googleapis.com"
    disable_on_destroy = false
}

# dataproc自動縮放政策(決定上限/下限)
resource "google_dataproc_autoscaling_policy" "ubike_weather_policy" {
  policy_id = "ubike-weather-policy" 
  project   = var.gcp_project_id 
  location    = var.gcp_region 
  
  # 核心 Worker 節點的配置
  worker_config {
    max_instances = 10
    min_instances = 2
    # 設置 Worker 擴縮比例
  }

  basic_algorithm {
    yarn_config {
      graceful_decommission_timeout = "30s"
      scale_down_factor = 0.5
      scale_up_factor   = 0.5
    }
  }
}

# 建立Servise Account
resource "google_service_account" "airflow_service_account"{
    account_id =var.service_account_id
}

# 建立服務帳號金鑰
resource "google_service_account_key" "airflow_key" {
  service_account_id = google_service_account.airflow_service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
  private_key_type   = "TYPE_GOOGLE_CREDENTIALS_FILE"
}

# 建立secretmanager
resource "google_project_service" "secretmanager" {
  project = var.gcp_project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}


# 建立一個 Secret Manager 密鑰來存放金鑰內容。
resource "google_secret_manager_secret" "airflow_key_secret" {
  depends_on = [google_project_service.secretmanager]

  secret_id = var.secret_id
  labels = {
    "managed-by" = "terraform"
  }

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}



# 將服務帳號金鑰的私鑰內容作為一個新版本，新增到 Secret Manager 密鑰中。
# 注意：`private_key` 是 Base64 編碼的，所以我們需要用 `base64decode` 轉換它。
resource "google_secret_manager_secret_version" "airflow_key_secret_version" {
  secret      = google_secret_manager_secret.airflow_key_secret.id
  secret_data = base64decode(google_service_account_key.airflow_key.private_key)
}

# 賦予需要使用這個金鑰的服務帳號（例如：用來執行 Airflow 的服務帳號）
# 讀取 Secret Manager 的權限。
resource "google_secret_manager_secret_iam_member" "consumer_iam" {
  secret_id = google_secret_manager_secret.airflow_key_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 將 GCS 儲存桶的 `storage.objectAdmin` 角色賦予服務帳號
resource "google_project_iam_member" "gcs_iam"{
    project=var.gcp_project_id
    role="roles/storage.objectAdmin"
    member="serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 將 BigQuery 資料集的 `bigquery.dataEditor` 角色賦予服務帳號
resource "google_project_iam_member" "bigquery_iam"{
    project=var.gcp_project_id
    role="roles/bigquery.dataEditor"
    member="serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 將 BigQuery 的 `bigquery.jobUser` 角色賦予服務帳號
# 這是為了讓服務帳號有權限執行查詢（即創建 BigQuery 工作）。
resource "google_project_iam_member" "bigquery_job_user_iam"{
    project=var.gcp_project_id
    role="roles/bigquery.jobUser"
    member="serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 賦予 Airflow 服務帳戶 Dataproc Editor 角色
# 這是讓它能夠建立、提交任務和刪除叢集的關鍵權限。
resource "google_project_iam_member" "dataproc_editor_iam" {
    project = var.gcp_project_id
    role    = "roles/dataproc.editor"
    # 確保 API 啟用後再賦予權限
    depends_on = [google_project_service.dataproc_api] 
    member  = "serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 賦予 Airflow 服務帳戶 Dataproc Worker 角色
# 這是讓服務帳號能夠在 Dataproc 叢集節點上運行 agent 的關鍵權限
resource "google_project_iam_member" "dataproc_worker_iam" {
    project = var.gcp_project_id
    role    = "roles/dataproc.worker"
    depends_on = [google_project_service.dataproc_api]
    member  = "serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 賦予 Compute Instance Admin V1 角色 (Autoscaling 必需)
# 這是為了讓 Dataproc 叢集的 Worker (使用此 SA) 有權限進行自動調度 (創建/刪除 VM 實例)。
resource "google_project_iam_member" "compute_instance_admin_iam" {
    project = var.gcp_project_id
    role    = "roles/compute.instanceAdmin.v1"
    member  = "serviceAccount:${google_service_account.airflow_service_account.email}"
}

# 這允許 Airflow SA (caller) 以 Dataproc 叢集 SA (subject) 的身份行動，
resource "google_project_iam_member" "dataproc_sa_user_iam" {
  project = var.gcp_project_id
  
  # 授予的角色：服務帳號使用者
  role    = "roles/iam.serviceAccountUser"
  
  # 誰被授予權限 (Airflow 的 SA)
  member = "serviceAccount:${google_service_account.airflow_service_account.email}"
  
  # **重要的條件**：指定該權限的目標 (Dataproc 叢集 SA)
  # 這裡使用 'Service Account User' 角色時，GCP 要求我們指定目標 SA 的完整名稱。
  # 由於您在 Dataproc 叢集配置中指定的 SA 已經被 Airflow SA 所用，通常直接在專案層級賦予此角色即可。
}


# 輸出服務帳號的電子郵件，方便其他資源使用
output "airflow_service_account_email" {
  value = google_service_account.airflow_service_account.email
}