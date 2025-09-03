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
    dataset_id="ubike_data_warehouse"
    description = "Dataset for storing transformed data models from dbt."
    location=var.gcp_region
}

# 布署 GCS_bucket
resource "google_storage_bucket" "data_lake_bucket"{
    name="${var.gcp_project_id}-data-lake"
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

# 建立Servise Account
resource "google_service_account" "airflow_service_account"{
    account_id ="airflow-service-account"
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

# 輸出服務帳號的電子郵件，方便其他資源使用
output "airflow_service_account_email" {
  value = google_service_account.airflow_service_account.email
}