#!/bin/bash

################################################################################
# GCP Infrastructure Setup Script
# Description: Automates the deployment of GCP infrastructure using Terraform
#              and Kubernetes manifests
# Author: DevOps Engineer
# Date: 2025-12-31
################################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly K8S_DIR="${SCRIPT_DIR}/k8s"
readonly LOG_FILE="${SCRIPT_DIR}/setup.log"

# GCP Configuration (can be overridden by environment variables)
GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"
GCP_REGION="${GCP_REGION:-us-central1}"
GCS_BUCKET_NAME="${GCS_BUCKET_NAME:-}"
GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-gke-autopilot-cluster}"

################################################################################
# Logging Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

################################################################################
# Utility Functions
################################################################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         GCP Infrastructure Automation Script                  ║"
    echo "║         Terraform + GKE Autopilot + Kubernetes                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_command_exists() {
    local cmd=$1
    if command -v "${cmd}" &> /dev/null; then
        log_success "${cmd} is installed ($(${cmd} --version 2>&1 | head -n1))"
        return 0
    else
        log_error "${cmd} is not installed"
        return 1
    fi
}

prompt_user_input() {
    local prompt_message=$1
    local variable_name=$2
    local current_value="${!variable_name}"
    
    if [[ -z "${current_value}" ]]; then
        read -p "${prompt_message}: " user_input
        eval "${variable_name}='${user_input}'"
    else
        log_info "Using ${variable_name}: ${current_value}"
    fi
}

################################################################################
# Step 1: Verify Required Tools
################################################################################

verify_prerequisites() {
    log_info "Step 1: Verifying prerequisites..."
    
    local all_tools_installed=true
    
    # Check gcloud
    if ! check_command_exists "gcloud"; then
        log_error "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
        all_tools_installed=false
    fi
    
    # Check terraform
    if ! check_command_exists "terraform"; then
        log_error "Please install Terraform: https://www.terraform.io/downloads"
        all_tools_installed=false
    fi
    
    # Check kubectl
    if ! check_command_exists "kubectl"; then
        log_error "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        all_tools_installed=false
    fi
    
    if [[ "${all_tools_installed}" == false ]]; then
        log_error "Missing required tools. Please install them and run this script again."
        exit 1
    fi
    
    log_success "All required tools are installed"
}

################################################################################
# Step 2: GCP Authentication
################################################################################

authenticate_gcp() {
    log_info "Step 2: Authenticating with GCP..."
    
    # Check if already authenticated
    if gcloud auth application-default print-access-token &> /dev/null; then
        log_warning "Already authenticated with application-default credentials"
        read -p "Do you want to re-authenticate? (y/N): " re_auth
        if [[ ! "${re_auth}" =~ ^[Yy]$ ]]; then
            log_info "Skipping authentication"
            return 0
        fi
    fi
    
    # Authenticate
    log_info "Opening browser for authentication..."
    if gcloud auth application-default login; then
        log_success "Successfully authenticated with GCP"
    else
        log_error "Authentication failed"
        exit 1
    fi
    
    # Also ensure user is logged in for gcloud commands
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_info "Logging in with user account..."
        gcloud auth login
    fi
}

################################################################################
# Step 3: Configure GCP Project
################################################################################

configure_gcp_project() {
    log_info "Step 3: Configuring GCP project..."
    
    # Get or prompt for project ID
    if [[ -z "${GCP_PROJECT_ID}" ]]; then
        log_info "Available GCP projects:"
        gcloud projects list --format="table(projectId,name,projectNumber)"
        echo ""
        prompt_user_input "Enter your GCP Project ID" GCP_PROJECT_ID
    fi
    
    # Set the project
    if gcloud config set project "${GCP_PROJECT_ID}"; then
        log_success "Set active project to: ${GCP_PROJECT_ID}"
    else
        log_error "Failed to set project"
        exit 1
    fi
    
    # Prompt for region if not set
    prompt_user_input "Enter GCP region (default: us-central1)" GCP_REGION
    GCP_REGION="${GCP_REGION:-us-central1}"
    
    # Set default bucket name if not provided
    if [[ -z "${GCS_BUCKET_NAME}" ]]; then
        GCS_BUCKET_NAME="${GCP_PROJECT_ID}-terraform-state"
        log_info "Using default bucket name: ${GCS_BUCKET_NAME}"
    fi
}

################################################################################
# Step 4: Create GCS Bucket for Terraform Backend
################################################################################

create_terraform_backend_bucket() {
    log_info "Step 4: Creating GCS bucket for Terraform backend..."
    
    # Check if bucket already exists
    if gsutil ls -b "gs://${GCS_BUCKET_NAME}" &> /dev/null; then
        log_warning "Bucket gs://${GCS_BUCKET_NAME} already exists"
        return 0
    fi
    
    log_info "Creating bucket: gs://${GCS_BUCKET_NAME}"
    
    # Create bucket with versioning enabled
    if gsutil mb -p "${GCP_PROJECT_ID}" -l "${GCP_REGION}" "gs://${GCS_BUCKET_NAME}"; then
        log_success "Bucket created successfully"
        
        # Enable versioning for state file protection
        if gsutil versioning set on "gs://${GCS_BUCKET_NAME}"; then
            log_success "Versioning enabled on bucket"
        else
            log_warning "Failed to enable versioning"
        fi
        
        # Enable uniform bucket-level access
        if gsutil uniformbucketlevelaccess set on "gs://${GCS_BUCKET_NAME}"; then
            log_success "Uniform bucket-level access enabled"
        else
            log_warning "Failed to enable uniform bucket-level access"
        fi
    else
        log_error "Failed to create bucket"
        exit 1
    fi
}

################################################################################
# Step 5: Initialize and Apply Terraform
################################################################################

run_terraform() {
    log_info "Step 5: Running Terraform..."
    
    # Check if terraform directory exists
    if [[ ! -d "${TERRAFORM_DIR}" ]]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        log_info "Please create a terraform directory with your configuration"
        exit 1
    fi
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform
    log_info "Running terraform init..."
    if terraform init -upgrade; then
        log_success "Terraform initialized successfully"
    else
        log_error "Terraform init failed"
        exit 1
    fi
    
    # Validate Terraform configuration
    log_info "Validating Terraform configuration..."
    if terraform validate; then
        log_success "Terraform configuration is valid"
    else
        log_error "Terraform validation failed"
        exit 1
    fi
    
    # Plan Terraform changes
    log_info "Running terraform plan..."
    if terraform plan -out=tfplan; then
        log_success "Terraform plan completed"
    else
        log_error "Terraform plan failed"
        exit 1
    fi
    
    # Prompt for apply confirmation
    echo ""
    log_warning "Review the plan above carefully"
    read -p "Do you want to apply these changes? (yes/no): " apply_confirm
    
    if [[ "${apply_confirm}" != "yes" ]]; then
        log_info "Terraform apply cancelled by user"
        cd "${SCRIPT_DIR}"
        return 0
    fi
    
    # Apply Terraform changes
    log_info "Running terraform apply..."
    if terraform apply tfplan; then
        log_success "Terraform apply completed successfully"
    else
        log_error "Terraform apply failed"
        cd "${SCRIPT_DIR}"
        exit 1
    fi
    
    # Clean up plan file
    rm -f tfplan
    
    cd "${SCRIPT_DIR}"
}

################################################################################
# Step 6: Configure kubectl for GKE Cluster
################################################################################

configure_kubectl() {
    log_info "Step 6: Configuring kubectl for GKE cluster..."
    
    # Prompt for cluster name if needed
    prompt_user_input "Enter GKE cluster name (default: gke-autopilot-cluster)" GKE_CLUSTER_NAME
    GKE_CLUSTER_NAME="${GKE_CLUSTER_NAME:-gke-autopilot-cluster}"
    
    # Get cluster credentials
    log_info "Fetching cluster credentials for: ${GKE_CLUSTER_NAME}"
    if gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" \
        --region="${GCP_REGION}" \
        --project="${GCP_PROJECT_ID}"; then
        log_success "kubectl configured successfully"
    else
        log_error "Failed to configure kubectl"
        log_warning "Make sure the cluster exists and is in the correct region"
        exit 1
    fi
    
    # Verify connection
    log_info "Verifying cluster connection..."
    if kubectl cluster-info &> /dev/null; then
        log_success "Successfully connected to cluster"
        kubectl get nodes
    else
        log_error "Failed to connect to cluster"
        exit 1
    fi
}

################################################################################
# Step 7: Apply Kubernetes Manifests
################################################################################

apply_kubernetes_manifests() {
    log_info "Step 7: Applying Kubernetes manifests..."
    
    # Check if k8s directory exists
    if [[ ! -d "${K8S_DIR}" ]]; then
        log_warning "Kubernetes manifests directory not found: ${K8S_DIR}"
        log_info "Skipping Kubernetes manifest deployment"
        return 0
    fi
    
    # Check if there are any YAML files
    if ! ls "${K8S_DIR}"/*.yaml &> /dev/null && ! ls "${K8S_DIR}"/*.yml &> /dev/null; then
        log_warning "No YAML files found in ${K8S_DIR}"
        log_info "Skipping Kubernetes manifest deployment"
        return 0
    fi
    
    # Apply all YAML files
    log_info "Applying manifests from ${K8S_DIR}..."
    
    local failed_files=()
    for manifest in "${K8S_DIR}"/*.{yaml,yml}; do
        # Skip if glob didn't match any files
        [[ -e "${manifest}" ]] || continue
        
        log_info "Applying: $(basename "${manifest}")"
        if kubectl apply -f "${manifest}"; then
            log_success "Applied: $(basename "${manifest}")"
        else
            log_error "Failed to apply: $(basename "${manifest}")"
            failed_files+=("${manifest}")
        fi
    done
    
    # Report results
    if [[ ${#failed_files[@]} -eq 0 ]]; then
        log_success "All Kubernetes manifests applied successfully"
    else
        log_error "Failed to apply ${#failed_files[@]} manifest(s):"
        for file in "${failed_files[@]}"; do
            log_error "  - $(basename "${file}")"
        done
        exit 1
    fi
    
    # Show deployed resources
    log_info "Deployed resources:"
    kubectl get all --all-namespaces
}

################################################################################
# Main Execution
################################################################################

main() {
    # Initialize log file
    echo "Setup started at $(date)" > "${LOG_FILE}"
    
    print_banner
    
    # Execute setup steps
    verify_prerequisites
    authenticate_gcp
    configure_gcp_project
    create_terraform_backend_bucket
    run_terraform
    configure_kubectl
    apply_kubernetes_manifests
    
    # Final summary
    echo ""
    log_success "╔════════════════════════════════════════════════════════════════╗"
    log_success "║  Setup completed successfully!                                ║"
    log_success "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log_info "Summary:"
    log_info "  - Project ID: ${GCP_PROJECT_ID}"
    log_info "  - Region: ${GCP_REGION}"
    log_info "  - GCS Bucket: ${GCS_BUCKET_NAME}"
    log_info "  - GKE Cluster: ${GKE_CLUSTER_NAME}"
    log_info "  - Log file: ${LOG_FILE}"
    echo ""
    log_info "Next steps:"
    log_info "  - Verify your deployments: kubectl get all -A"
    log_info "  - Check cluster status: gcloud container clusters list"
    log_info "  - View logs: cat ${LOG_FILE}"
}

# Trap errors and cleanup
trap 'log_error "Script failed at line $LINENO"' ERR

# Run main function
main "$@"
