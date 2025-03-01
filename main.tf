data "google_compute_default_service_account" "default" {
  project = var.project_id
}

resource "google_project_iam_member" "compute_instance_admin_role" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}


resource "google_compute_instance" "vm_instance" {
  name         = "cloudroot7"
  machine_type = "e2-micro"
  zone         = var.zone

  allow_stopping_for_update = true

  metadata = {
    enable-guest-attributes = "TRUE"
    enable-osconfig         = "TRUE"
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  labels = {
    env = "production"
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = <<-EOF
     #!/bin/bash
     sudo apt-get update 
   curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
   sudo bash add-google-cloud-ops-agent-repo.sh --also-install
   EOF
  depends_on              = [time_sleep.wait_project_init]
}


resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "Disk utilization crossed threshold"
  type         = "email"

  labels = {
    email_address = "avish@gmail.com" # Replace with your email
  }
}


resource "google_monitoring_alert_policy" "memory_alert" {
  display_name = "Memory Utilization Alert"
  #notification_channel = "Disk utilization crossed threshold"  # Replace with your notification channel ID
  combiner = "OR"
  conditions {
    display_name = "Memory Utilization High"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/disk/write_bytes_count\" AND resource.type=\"gce_instance\" AND resource.labels.instance_id=\"7771777848152174577\""
      comparison      = "COMPARISON_GT"
      threshold_value = 40
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  /*alert_strategy {
    notification_rate_limit {
      period = "60s"
    }
  }*/

  enabled               = true
  notification_channels = [google_monitoring_notification_channel.email_channel.id]
}
