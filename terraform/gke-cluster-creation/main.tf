# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Definition of local variables

# Create GKE cluster
module "gke_auth" {
  source = "terraform-google-modules/kubernetes-engine/google"
  depends_on   = [module.gke]
  project_id   = var.project_id
  location     = module.gke.location
  cluster_name = module.gke.name
}
resource "local_file" "kubeconfig" {
  content  = module.gke_auth.kubeconfig_raw
  filename = "kubeconfig-${var.env_name}"
}
module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  version      = "~> 3.0"
  project_id   = var.project_id
  network_name = "${var.network}-${var.env_name}"
  subnets = [
    {
      subnet_name   = "${var.subnetwork}-${var.env_name}"
      subnet_ip     = "10.0.0.0/16"
      subnet_region = var.region
    },
  ]
  secondary_ranges = {
    "${var.subnetwork}-${var.env_name}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "10.1.0.0/16"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "10.2.0.0/16"
      },
    ]
  }
}

module "gke" {
  source                 = "terraform-google-modules/kubernetes-engine/google//modules/public-cluster"
  project_id             = var.project_id
  name                   = "${var.cluster_name}-${var.env_name}"
  regional               = true
  region                 = var.region
  network                = module.gcp-network.network_name
  subnetwork             = module.gcp-network.subnets_names[0]
  ip_range_pods          = var.ip_range_pods_name
  ip_range_services      = var.ip_range_services_name
  node_pools = [
    {
      name                      = "node-pool"
      machine_type              = "e2-medium"
      node_locations            = "europe-west1-b,europe-west1-c,europe-west1-d"
      min_count                 = 1
      max_count                 = 2
      disk_size_gb              = 30
    },
  ]
}
