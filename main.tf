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

# 啟用 Dataproc 服務
resource "google_project_service" "dataproc_api" {
    project = var.gcp_project_id
    service = "dataproc.googleapis.com"
    disable_on_destroy = false
}

# 啟用 Vertex AI 服務 (Workbench 所需)
resource "google_project_service" "vertex_ai_api" {
    project = var.gcp_project_id
    service = "aiplatform.googleapis.com"
    disable_on_destroy = false
}

# 啟用 Notebooks API (底層 API，是 Vertex AI Workbench 實例的運行基礎)
resource "google_project_service" "notebooks_api" {
    project = var.gcp_project_id
    service = "notebooks.googleapis.com"
    disable_on_destroy = false
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


# 輸出服務帳號的電子郵件，方便其他資源使用
output "airflow_service_account_email" {
  value = google_service_account.airflow_service_account.email
}