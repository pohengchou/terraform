variable "gcp_project_id" {
    description="The ID of the GCP project to deploy resources into."
    type= string
}

variable "gcp_region" {
    description="resources region"
    type= string
}

variable "staging_bucket_name" {
  description = "The name of the GCS bucket used for Dataproc staging."
}

variable "service_account_email" {
  description = "The email of the Dataproc service account."
}