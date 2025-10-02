## 🏗️ Terraform (Infrastructure as Code) - GCP 資源自動化部署

本專案使用 **Terraform** 在 **GCP** 上實現 **Ubike ELT** 架構的 IaC 部署，確保環境具備**可複製性**和**版本控制**。

### 核心檔案功能一覽

| 檔案名稱 | 核心工程亮點 (強調 IaC 價值) |
| :--- | :--- |
| **`main.tf`** | **資源骨幹部署**：定義 GCS (Data Lake)、BigQuery (Data Warehouse) 並配置 **IAM 權限**與 **Secret Manager** 整合，安全管理服務金鑰。 |
| **`vm.tf`** | **Airflow 執行環境**：定義 $\text{Compute Engine VM}$ 配置，**綁定專用服務帳號**，並設定防火牆規則 (開 $\text{Port 8080}$ 供 $\text{Airflow UI}$ 使用)。 |
| **`startup-script.sh`** | **零接觸部署**：VM 啟動時自動安裝 $\text{Docker}$、$\text{Airflow}$ 依賴，實現環境的**自動化初始化**。 |
| **`variable.tf`** | **參數化**：定義專案 $\text{ID}$、區域等參數，使架構可快速部署至不同環境。 |

### 安全與狀態管理

* **`.gitignore`**：已忽略 `terraform.tfvars` 和 `terraform.tfstate` 等敏感檔案，遵循 $\text{IaC}$ **安全最佳實踐**。