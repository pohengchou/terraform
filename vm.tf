
# 布署 VM
resource "google_compute_instance" "airflow_vm" {
  name         = "${var.gcp_project_id}-airflow-vm"
  machine_type = var.gcp_machine_type
  zone         = "${var.gcp_region}-b"

  # Add a network tag to allow the firewall rule to apply to this VM.
  tags = ["airflow-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20250805"
    }
  }