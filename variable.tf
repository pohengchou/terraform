variable "gcp_project_id" {
    description="The ID of the GCP project to deploy resources into."
    type= string
}

variable "gcp_region" {
    description="resources region"
    type= string
}

# 定義 VM 的機器類型 (例如: "e2-medium", "e2-highmem-4")
variable "gcp_machine_type" {
  type        = string
  description = "The machine type for the Google Compute Engine VM."
}

#硬碟容量
variable "gcp_disk_size_gb" {
  type= number
  description =  "The size of the boot disk in GB."
}

# 允許的IP位置
variable "allowed_ip"{
  type = string
  description= "IP which allowed to connect this project"
}