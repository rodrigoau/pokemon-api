# main.tf

# 1. Definimos la versión exacta del proveedor de Helm que necesitamos
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# 2. Le decimos a Terraform que se conecte a nuestro Kubernetes (Minikube)
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# 3. Instruimos a Terraform para que instale nuestro Chart de Helm
resource "helm_release" "pokemon_api" {
  name  = "pokemon-release"        
  chart = "./pokemon-api-chart"    

  set {
    name  = "image.repository"
    value = "pokemon-api"
  }
  set {
    name  = "image.tag"
    value = "v4"
  }
  set {
    name  = "image.pullPolicy"
    value = "Never" 
  }
  set {
    name  = "service.port"
    value = "8000"
  }
  set {
    name  = "livenessProbe.httpGet.path"
    value = "/health"
  }
  set {
    name  = "readinessProbe.httpGet.path"
    value = "/health"
  }
}