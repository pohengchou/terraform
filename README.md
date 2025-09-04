# YouBike 資料管線 - GCP 基礎設施部署

這個程式碼倉庫包含了使用 **Terraform** 部署 YouBike 資料管線專案所需的全部 Google Cloud Platform (GCP) 基礎設施。

此倉庫的目標是實現基礎設施的自動化部署與管理，確保專案環境的可重複性、一致性與可擴展性。

## 專案部署的 GCP 資源

本專案透過 Terraform 部署以下核心 GCP 資源：

* **Google Compute Engine (GCE) VM 實例**：一台 Ubuntu 虛擬機，將用作 Airflow 部署的主機。

* **服務帳號 (Service Account)**：專門為 Airflow 虛擬機建立，並賦予其必要的權限，以便存取 BigQuery、Cloud Storage 等 GCP 服務。

* **防火牆規則 (Firewall Rules)**：設定網路規則，僅允許特定 IP 位址對 Airflow VM 進行 SSH 連線 (Port 22)，並開放 Airflow Web UI 介面 (Port 8080)。

* **靜態 IP 位址 (Static IP Address)**：為虛擬機分配一個固定的公用 IP，以確保連線穩定性。

## 部署指南

### 前置條件

在開始部署之前，請確認你已完成以下準備：

1. **安裝 Terraform**：確保你的本機環境已安裝 Terraform。

2. **安裝 Google Cloud SDK**：並使用 `gcloud auth login` 登入你的 GCP 帳號。

3. **建立服務帳號金鑰**：為你的專案建立一個服務帳號金鑰，並將其 `.json` 檔案儲存在安全位置。

4. **設定環境變數**：在你的終端機中，設定 `GOOGLE_APPLICATION_CREDENTIALS` 環境變數，指向你的金鑰檔案路徑。

### 部署步驟

1. **複製程式碼倉庫**：


git clone https://github.com/pohengchou/terraform
cd terraform


2. **配置變數**：

* 編輯 `dev.tfvars` 檔案，將 `gcp_project_id` 和 `gcp_service_account` 替換為你的實際資訊。

* 如果需要，你也可以將 `allowed_ip` 替換為你的靜態 IP 位址以提高安全性。

3. **執行 Terraform**：

* 初始化 Terraform 專案：

  ```
  terraform init
  ```

* 預覽將要部署的資源，確認無誤：

  ```
  terraform plan
  ```

* 執行部署：

  ```
  terraform apply
  ```

在提示時輸入 `yes` 以確認部署。

## 部署後的輸出

當 `terraform apply` 成功執行後，它會自動輸出 Airflow VM 的公用 IP 位址。


terraform output airflow_vm_public_ip


## 注意事項

* 為了確保安全，請**不要**將 `dev.tfvars` 或任何包含敏感資訊的檔案提交到 Git 倉庫。本專案已包含 `.gitignore` 檔案來協助你管理這些檔案。

* 如果你需要**刪除**所有部署的資源，可以使用 `terraform destroy` 指令。
