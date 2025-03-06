#!/bin/bash
set -euo pipefail

# Script to set up GitHub Actions secrets and variables for CI/CD workflow
# Prerequisites: GitHub CLI (gh) installed and authenticated

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed or not in PATH"
    echo "Please install it from https://cli.github.com/ and authenticate with 'gh auth login'"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub CLI"
    echo "Please run 'gh auth login' first"
    exit 1
fi

# Get the current repository
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
if [ -z "$REPO" ]; then
    echo "Error: Could not determine current repository"
    echo "Please run this script from within a GitHub repository"
    exit 1
fi

echo "Setting up CI/CD configuration for repository: $REPO"
echo "---------------------------------------------------"

# Function to set a GitHub secret
set_secret() {
    local name=$1
    local value=$2
    local description=$3
    
    echo "Setting secret: $name - $description"
    echo "$value" | gh secret set "$name" --repo "$REPO"
    echo "✅ Secret '$name' set successfully"
}

# Function to set a GitHub variable
set_variable() {
    local name=$1
    local value=$2
    local description=$3
    
    echo "Setting variable: $name - $description"
    gh variable set "$name" --body "$value" --repo "$REPO"
    echo "✅ Variable '$name' set successfully"
}

# Function to get input with a default value
get_input_with_default() {
    local prompt=$1
    local default=$2
    local input
    
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# Function to get a secret value (doesn't echo to terminal)
get_secret_input() {
    local prompt=$1
    local secret
    
    read -s -p "$prompt: " secret
    echo
    echo "$secret"
}

echo
echo "Setting up GitHub Secrets (sensitive information)"
echo "------------------------------------------------"

# SERVER_ADMIN_KEY
SERVER_ADMIN_KEY=$(get_secret_input "Enter SERVER_ADMIN_KEY (private key for server admin)")
set_secret "SERVER_ADMIN_KEY" "$SERVER_ADMIN_KEY" "Private key for server admin"

# SETTLER_PRIVATE_ACCOUNT
SETTLER_PRIVATE_ACCOUNT=$(get_secret_input "Enter SETTLER_PRIVATE_ACCOUNT (private key for settler account)")
set_secret "SETTLER_PRIVATE_ACCOUNT" "$SETTLER_PRIVATE_ACCOUNT" "Private key for settler account"

# USER_ADDRESS
USER_ADDRESS=$(get_input_with_default "Enter USER_ADDRESS (public address for the account)" "")
set_secret "USER_ADDRESS" "$USER_ADDRESS" "Public address for the account"

# K8S_SECRET_NAME - changed from secret to variable for consistency
K8S_SECRET_NAME=$(get_input_with_default "Enter Kubernetes secret name" "app-secrets")
set_variable "K8S_SECRET_NAME" "$K8S_SECRET_NAME" "Name of the Kubernetes secret"

# KUBE_CONFIG
echo "For KUBE_CONFIG, you can either:"
echo "1. Enter the kubeconfig content directly (recommended)"
echo "2. Let the script read your kubeconfig file"
read -p "Choose option (1/2): " kube_option

if [ "$kube_option" = "1" ]; then
    echo "Please paste your kubeconfig content (press Ctrl+D when done):"
    KUBE_CONFIG=$(cat)
else
    KUBECONFIG_PATH=$(get_input_with_default "Enter path to kubeconfig file" "$HOME/.kube/config")
    if [ ! -f "$KUBECONFIG_PATH" ]; then
        echo "Error: Kubeconfig file not found at $KUBECONFIG_PATH"
        exit 1
    fi
    KUBE_CONFIG=$(cat "$KUBECONFIG_PATH")
    echo "Kubeconfig file read successfully"
fi

# Validate kubeconfig format
if [[ "$KUBE_CONFIG" == *"apiVersion"* ]]; then
    echo "✅ Kubeconfig appears to be valid (contains apiVersion)"
else
    echo "⚠️ Warning: Kubeconfig does not contain 'apiVersion', it may be invalid"
    echo "Please verify your kubeconfig is in the correct format"
    read -p "Continue anyway? (y/n): " continue_option
    if [ "$continue_option" != "y" ]; then
        echo "Aborting setup"
        exit 1
    fi
fi

set_secret "KUBE_CONFIG" "$KUBE_CONFIG" "Kubernetes configuration"

echo
echo "Setting up GitHub Variables (configuration)"
echo "-----------------------------------------"

# CHART_NAME (optional)
CHART_NAME=$(get_input_with_default "Enter CHART_NAME (optional, defaults to repo name)" "")
if [ -n "$CHART_NAME" ]; then
    set_variable "CHART_NAME" "$CHART_NAME" "Name for your Helm chart"
else
    echo "Skipping CHART_NAME, will use repository name as default"
fi

# CHAIN_ID
CHAIN_ID=$(get_input_with_default "Enter CHAIN_ID" "11155111")
set_variable "CHAIN_ID" "$CHAIN_ID" "Blockchain network ID"

# ALLOWED_ORIGINS
ALLOWED_ORIGINS=$(get_input_with_default "Enter ALLOWED_ORIGINS" "*")
set_variable "ALLOWED_ORIGINS" "$ALLOWED_ORIGINS" "CORS allowed origins"

# K8S_NAMESPACE
echo "IMPORTANT: The K8S_NAMESPACE variable is used to determine which Kubernetes namespace to deploy to."
echo "This is a critical setting that affects where your application will be deployed."
K8S_NAMESPACE=$(get_input_with_default "Enter Kubernetes namespace" "zkwasm")
set_variable "K8S_NAMESPACE" "$K8S_NAMESPACE" "Kubernetes namespace for deployment"
echo "✅ K8S_NAMESPACE set to: $K8S_NAMESPACE"

# DEPLOY_ENABLED
DEPLOY_ENABLED=$(get_input_with_default "Enable deployment functionality (true/false)" "true")
set_variable "DEPLOY_ENABLED" "$DEPLOY_ENABLED" "Whether to enable deployment functionality"

# REMOTE_MODE
REMOTE_MODE=$(get_input_with_default "Enable remote mode (true/false)" "true")
set_variable "REMOTE_MODE" "$REMOTE_MODE" "Whether to run in remote mode"

# AUTO_SUBMIT
AUTO_SUBMIT=$(get_input_with_default "Enable auto-submission (true/false/empty)" "true")
set_variable "AUTO_SUBMIT" "$AUTO_SUBMIT" "Whether to enable auto-submission"

# STORAGE_CLASS_NAME
STORAGE_CLASS_NAME=$(get_input_with_default "Enter Kubernetes storage class name" "csi-disk")
set_variable "STORAGE_CLASS_NAME" "$STORAGE_CLASS_NAME" "Kubernetes storage class name for persistent volumes"

# CREATOR_ONLY_ADD_PROVE_TASK
CREATOR_ONLY_ADD_PROVE_TASK=$(get_input_with_default "Enable creator-only prove task (true/false)" "true")
set_variable "CREATOR_ONLY_ADD_PROVE_TASK" "$CREATOR_ONLY_ADD_PROVE_TASK" "Whether to restrict prove tasks to creator only"

echo
echo "✅ All GitHub secrets and variables have been set up successfully!"
echo "You can now run your CI/CD workflow by pushing to the main branch."
echo
echo "To verify your configuration, run:"
echo "  gh secret list --repo $REPO"
echo "  gh variable list --repo $REPO"
