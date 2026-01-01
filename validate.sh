#!/bin/bash

################################################################################
# GCP Infrastructure Validation Script
# Description: Validates that all resources are deployed correctly
################################################################################

set -euo pipefail

# Color codes
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         GCP Infrastructure Validation                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check GCP Authentication
echo -e "${BLUE}[1/6] Checking GCP Authentication...${NC}"
if gcloud auth application-default print-access-token &> /dev/null; then
    echo -e "${GREEN}✓ GCP Authentication: OK${NC}"
else
    echo -e "${RED}✗ GCP Authentication: FAILED${NC}"
    exit 1
fi

# Check Active Project
echo -e "${BLUE}[2/6] Checking Active Project...${NC}"
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -n "${PROJECT_ID}" ]]; then
    echo -e "${GREEN}✓ Active Project: ${PROJECT_ID}${NC}"
else
    echo -e "${RED}✗ No active project set${NC}"
    exit 1
fi

# Check Terraform State Bucket
echo -e "${BLUE}[3/6] Checking Terraform State Bucket...${NC}"
BUCKET_NAME="${PROJECT_ID}-terraform-state"
if gsutil ls -b "gs://${BUCKET_NAME}" &> /dev/null; then
    echo -e "${GREEN}✓ Terraform State Bucket: gs://${BUCKET_NAME}${NC}"
else
    echo -e "${YELLOW}⚠ Terraform State Bucket not found${NC}"
fi

# Check GKE Cluster
echo -e "${BLUE}[4/6] Checking GKE Cluster...${NC}"
CLUSTER_COUNT=$(gcloud container clusters list --format="value(name)" | wc -l)
if [[ ${CLUSTER_COUNT} -gt 0 ]]; then
    echo -e "${GREEN}✓ GKE Clusters found:${NC}"
    gcloud container clusters list --format="table(name,location,status)"
else
    echo -e "${YELLOW}⚠ No GKE clusters found${NC}"
fi

# Check kubectl Configuration
echo -e "${BLUE}[5/6] Checking kubectl Configuration...${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ kubectl is configured${NC}"
    CURRENT_CONTEXT=$(kubectl config current-context)
    echo -e "${GREEN}  Current context: ${CURRENT_CONTEXT}${NC}"
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo -e "${GREEN}  Nodes: ${NODE_COUNT}${NC}"
else
    echo -e "${YELLOW}⚠ kubectl not configured or cluster not accessible${NC}"
fi

# Check Kubernetes Resources
echo -e "${BLUE}[6/6] Checking Kubernetes Resources...${NC}"
if kubectl get namespaces demo-app &> /dev/null; then
    echo -e "${GREEN}✓ Namespace 'demo-app' exists${NC}"
    
    # Check deployments
    DEPLOY_COUNT=$(kubectl get deployments -n demo-app --no-headers 2>/dev/null | wc -l)
    echo -e "${GREEN}  Deployments: ${DEPLOY_COUNT}${NC}"
    
    # Check services
    SVC_COUNT=$(kubectl get services -n demo-app --no-headers 2>/dev/null | wc -l)
    echo -e "${GREEN}  Services: ${SVC_COUNT}${NC}"
    
    # Check pods
    POD_COUNT=$(kubectl get pods -n demo-app --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods -n demo-app --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo -e "${GREEN}  Pods: ${RUNNING_PODS}/${POD_COUNT} running${NC}"
    
    # Check for LoadBalancer IP
    echo ""
    echo -e "${BLUE}LoadBalancer Service:${NC}"
    kubectl get svc -n demo-app -o wide
else
    echo -e "${YELLOW}⚠ Namespace 'demo-app' not found${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Validation Complete!                                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Summary
echo -e "${BLUE}Quick Commands:${NC}"
echo -e "  View all resources:    ${YELLOW}kubectl get all -A${NC}"
echo -e "  View logs:             ${YELLOW}kubectl logs -f <pod-name> -n demo-app${NC}"
echo -e "  Terraform outputs:     ${YELLOW}cd terraform && terraform output${NC}"
echo -e "  Cluster info:          ${YELLOW}gcloud container clusters list${NC}"
echo ""
