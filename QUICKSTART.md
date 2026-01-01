# 🚀 Quick Start Guide

## Configuración Inicial (5 minutos)

### 1. Configurar Variables de Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con tu información:

```hcl
project_id   = "tu-proyecto-gcp"
region       = "us-central1"
cluster_name = "gke-autopilot-cluster"
environment  = "dev"
```

### 2. Configurar Backend de Terraform

Edita `terraform/backend.tf` y descomenta las líneas del backend:

```hcl
backend "gcs" {
  bucket  = "tu-proyecto-gcp-terraform-state"
  prefix  = "terraform/state"
}
```

### 3. Ejecutar el Script de Setup

```bash
./setup.sh
```

El script te pedirá:

- **Project ID**: Tu ID de proyecto GCP
- **Region**: Región donde desplegar (default: us-central1)
- **Cluster Name**: Nombre del cluster GKE (default: gke-autopilot-cluster)

## ⏱️ Tiempos Estimados

- **Autenticación**: 1-2 minutos
- **Creación de bucket**: 30 segundos
- **Terraform init**: 30 segundos
- **Terraform apply**: 10-15 minutos (GKE Autopilot)
- **Configuración kubectl**: 30 segundos
- **Aplicación de manifiestos K8s**: 1-2 minutos

**Total**: ~15-20 minutos

## 🎯 Verificación Rápida

Después de ejecutar el script:

```bash
# Ver cluster
gcloud container clusters list

# Ver nodos
kubectl get nodes

# Ver pods
kubectl get pods -n demo-app

# Ver servicios
kubectl get svc -n demo-app

# Obtener IP externa del LoadBalancer
kubectl get svc nginx-service -n demo-app -w
```

## 🔧 Comandos Útiles

### Terraform

```bash
cd terraform

# Ver estado actual
terraform show

# Ver outputs
terraform output

# Destruir infraestructura
terraform destroy
```

### Kubernetes

```bash
# Ver todos los recursos
kubectl get all -A

# Ver logs de un pod
kubectl logs -f <pod-name> -n demo-app

# Describir un recurso
kubectl describe pod <pod-name> -n demo-app

# Ejecutar comando en un pod
kubectl exec -it <pod-name> -n demo-app -- /bin/sh
```

### GCloud

```bash
# Ver proyecto actual
gcloud config get-value project

# Listar clusters
gcloud container clusters list

# Ver detalles del cluster
gcloud container clusters describe gke-autopilot-cluster --region us-central1

# Ver buckets
gsutil ls
```

## 🧹 Limpieza

Para eliminar todos los recursos:

```bash
# 1. Eliminar recursos de Kubernetes
kubectl delete namespace demo-app

# 2. Destruir infraestructura de Terraform
cd terraform
terraform destroy

# 3. (Opcional) Eliminar bucket de estado
gsutil rm -r gs://tu-proyecto-gcp-terraform-state
```

## 📝 Notas Importantes

- **Costos**: GKE Autopilot tiene costos asociados. Revisa la [calculadora de precios de GCP](https://cloud.google.com/products/calculator)
- **Permisos**: Necesitas permisos de Editor o Owner en el proyecto GCP
- **Cuotas**: Verifica que tu proyecto tenga cuotas suficientes para GKE

## 🆘 Problemas Comunes

### "Permission denied"

```bash
chmod +x setup.sh
```

### "Project not found"

```bash
gcloud projects list
# Verifica que el Project ID sea correcto
```

### "Quota exceeded"

Solicita aumento de cuota en la consola de GCP

### "Cluster not found"

Espera 10-15 minutos para que el cluster termine de crearse

## 📚 Recursos

- [Documentación GKE Autopilot](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
