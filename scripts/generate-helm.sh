#!/bin/bash
set -euo pipefail

# Get repository name for default CHART_NAME
REPO_URL=$(git config --get remote.origin.url)
if [[ $REPO_URL == *"github.com"* ]]; then
  if [[ $REPO_URL == *":"* ]]; then
    REPO_NAME=$(echo $REPO_URL | sed -E 's/.*:[^/]+\/([^/\.]+)(\.git)?$/\1/')
  else
    REPO_NAME=$(echo $REPO_URL | sed -E 's/.*github\.com\/[^/]+\/([^/\.]+)(\.git)?$/\1/')
  fi
  REPO_NAME=$(echo $REPO_NAME | tr '[:upper:]' '[:lower:]')
else
  REPO_NAME="zkwasm-exchange"
  echo "Warning: Not a GitHub repository or couldn't determine name. Using default: $REPO_NAME"
fi

# Environment Variables with defaults from GitHub Actions
# Use CHART_NAME from GitHub variables if provided, otherwise use repo name
CHART_NAME="${CHART_NAME:-$REPO_NAME}"
CHAIN_ID="${CHAIN_ID:-11155111}" # Default to Sepolia testnet
ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-*}" # Multiple domains separated by commas
CHART_PATH="./helm-charts/${CHART_NAME}"

# Echo important variables for debugging
echo "CHART_NAME: ${CHART_NAME}"
echo "CHART_PATH: ${CHART_PATH}"
DEPLOY_VALUE="${DEPLOY_VALUE:-true}" 
REMOTE_VALUE="${REMOTE_VALUE:-true}" 
AUTO_SUBMIT_VALUE="${AUTO_SUBMIT_VALUE:-}" # Default to empty
K8S_NAMESPACE="${K8S_NAMESPACE:-zkwasm}" # Default namespace
STORAGE_CLASS_NAME="${STORAGE_CLASS_NAME:-csi-disk}" # Make storage class configurable
K8S_SECRET_NAME="${K8S_SECRET_NAME:-app-secrets}" # Default secret name
CREATOR_ONLY_ADD_PROVE_TASK="${CREATOR_ONLY_ADD_PROVE_TASK:-true}" # Whether to restrict prove tasks to creator only

echo "Using CHART_NAME: ${CHART_NAME}"
echo "Using K8S_NAMESPACE: ${K8S_NAMESPACE}"

# IMAGE_VALUE must be the MD5 value of the WASM file
# Check if build-artifacts directory exists
if [[ ! -d "build-artifacts" ]]; then
  echo "ERROR: build-artifacts directory not found"
  echo "Creating build-artifacts directory..."
  mkdir -p build-artifacts
  
  # Check if we're in CI environment
  if [[ -n "${CI:-}" ]]; then
    echo "ERROR: In CI environment, build-artifacts directory should have been created during build stage"
    echo "Please ensure the Docker build process is correctly generating the build artifacts"
    exit 1
  fi
  
  # If not in CI, try to generate the MD5 if the WASM file exists elsewhere
  if [[ -f "./ts/node_modules/zkwasm-ts-server/src/application/application_bg.wasm" ]]; then
    echo "Found WASM file in expected location, generating MD5..."
    md5sum ./ts/node_modules/zkwasm-ts-server/src/application/application_bg.wasm | \
    awk '{print toupper($1)}' > build-artifacts/wasm.md5
    cp ./ts/node_modules/zkwasm-ts-server/src/application/application_bg.wasm build-artifacts/
  else
    echo "ERROR: WASM file not found in expected location"
    echo "Please build the WASM file first using 'make build'"
    exit 1
  fi
fi

# Check if wasm.md5 file exists
if [[ -f "build-artifacts/wasm.md5" ]]; then
  IMAGE_VALUE="$(cat build-artifacts/wasm.md5)"
  echo "Using WASM MD5 from build-artifacts: ${IMAGE_VALUE}"
  
  # Validate MD5 format (should be 32 hex characters)
  if ! [[ "$IMAGE_VALUE" =~ ^[A-F0-9]{32}$ ]]; then
    echo "ERROR: Invalid MD5 format in build-artifacts/wasm.md5: ${IMAGE_VALUE}"
    echo "MD5 should be 32 hexadecimal characters (uppercase)"
    exit 1
  fi
else
  # If no MD5 is available, exit with error
  echo "ERROR: build-artifacts/wasm.md5 not found and IMAGE_VALUE must be an MD5 value"
  echo "Please build the WASM file first to generate the MD5 value"
  exit 1
fi

# Validate numeric chain ID
if ! [[ "$CHAIN_ID" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid CHAIN_ID '$CHAIN_ID' - must be numeric"
  exit 1
fi

# Validate K8S_SECRET_NAME is set when running in CI
if [[ -n "${CI:-}" && -z "${K8S_SECRET_NAME:-}" ]]; then
  echo "ERROR: K8S_SECRET_NAME must be set in CI environment"
  exit 1
fi

echo "Using IMAGE_VALUE: ${IMAGE_VALUE}"

mkdir -p ${CHART_PATH}/templates

helm create ${CHART_PATH}

rm -f ${CHART_PATH}/templates/deployment.yaml
rm -f ${CHART_PATH}/templates/service.yaml
rm -f ${CHART_PATH}/templates/serviceaccount.yaml
rm -f ${CHART_PATH}/templates/hpa.yaml
rm -f ${CHART_PATH}/templates/ingress.yaml
rm -f ${CHART_PATH}/templates/NOTES.txt
rm -f ${CHART_PATH}/values.yaml

cat > ${CHART_PATH}/templates/mongodb-pvc.yaml << EOL
{{- if and .Values.config.mongodb.enabled .Values.config.mongodb.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-mongodb-pvc
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
  annotations:
    "helm.sh/resource-policy": keep
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.config.mongodb.persistence.size }}
  storageClassName: {{ .Values.config.mongodb.persistence.storageClassName }}
{{- end }}
EOL

REPO_URL=$(git config --get remote.origin.url)
if [[ $REPO_URL == *"github.com"* ]]; then
  if [[ $REPO_URL == *":"* ]]; then
    REPO_OWNER=$(echo $REPO_URL | sed -E 's/.*:([^\/]+)\/[^\/]+.*/\1/')
  else
    REPO_OWNER=$(echo $REPO_URL | sed -E 's/.*github\.com\/([^\/]+).*/\1/')
  fi
  
  REPO_OWNER=$(echo $REPO_OWNER | sed 's/https:\/\///g' | sed 's/http:\/\///g')
  
  REPO_OWNER=$(echo $REPO_OWNER | sed 's/github\.com\///g' | sed 's/\/.*//g')
  
  REPO_OWNER=$(echo $REPO_OWNER | tr '[:upper:]' '[:lower:]')
else
  REPO_OWNER="jupiterxiaoxiaoyu"
  echo "Warning: Not a GitHub repository or couldn't determine owner. Using default: $REPO_OWNER"
fi

echo "Using repository owner: $REPO_OWNER"

cat > ${CHART_PATH}/values.yaml << EOL
# Default values for ${CHART_NAME}
replicaCount: 1

# Namespace for the deployment
namespace: "${K8S_NAMESPACE}"

image:
  repository: ghcr.io/${REPO_OWNER}/${CHART_NAME}
  pullPolicy: Always
  tag: "latest"  # Could be latest or MD5 value

ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    enabled: true
  domain:
    base: "zkwasm.ai"
    prefix: "rpc"  # Generate rpc.namespace.zkwasm.ai
  cors:
    enabled: true
    allowOrigins: "${ALLOWED_ORIGINS}"
    allowMethods: "GET, PUT, POST, DELETE, PATCH, OPTIONS"
    allowHeaders: "DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization"
    allowCredentials: "true"
    maxAge: "1728000"

config:
  app:
    deploy: "${DEPLOY_VALUE}"
    remote: "${REMOTE_VALUE}"
    autoSubmit: "${AUTO_SUBMIT_VALUE}"
    image: "${IMAGE_VALUE}"
  mongodb:
    enabled: true
    image:
      repository: mongo
      tag: latest
    port: 27017
    persistence:
      enabled: true
      storageClassName: ${STORAGE_CLASS_NAME}  
      size: 10Gi
  redis:
    enabled: true
    image:
      repository: redis
      tag: latest
    port: 6379
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
  merkle:
    enabled: true
    image:
      repository: sinka2022/zkwasm-merkleservice
      tag: latest
    port: 3030

service:
  type: ClusterIP
  port: 3000

# 初始化容器配置
initContainer:
  enabled: true
  image: node:18-slim

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 128Mi

nodeSelector: {}
tolerations: []
affinity: {}
EOL

cat > ${CHART_PATH}/templates/deployment.yaml << EOL
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-rpc
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "${CHART_NAME}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "${CHART_NAME}.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: app
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        command: ["node"]
        args: ["--experimental-modules", "--es-module-specifier-resolution=node", "ts/src/service.js"]
        env:
        - name: URI
          value: mongodb://{{ include "${CHART_NAME}.fullname" . }}-mongodb:{{ .Values.config.mongodb.port }}
        - name: REDISHOST
          value: {{ include "${CHART_NAME}.fullname" . }}-redis
        - name: REDIS_PORT
          value: "{{ .Values.config.redis.port }}"
        - name: MERKLE_SERVER
          value: http://{{ include "${CHART_NAME}.fullname" . }}-merkle:{{ .Values.config.merkle.port }}
        - name: SERVER_ADMIN_KEY
          valueFrom:
            secretKeyRef:
              name: ${K8S_SECRET_NAME}
              key: SERVER_ADMIN_KEY
        - name: USER_ADDRESS
          valueFrom:
            secretKeyRef:
              name: ${K8S_SECRET_NAME}
              key: USER_ADDRESS
        - name: USER_PRIVATE_ACCOUNT
          valueFrom:
            secretKeyRef:
              name: ${K8S_SECRET_NAME}
              key: USER_PRIVATE_ACCOUNT
              optional: true
        # Fallback to SETTLER_PRIVATE_ACCOUNT if USER_PRIVATE_ACCOUNT is not found
        - name: SETTLER_PRIVATE_ACCOUNT
          valueFrom:
            secretKeyRef:
              name: ${K8S_SECRET_NAME}
              key: SETTLER_PRIVATE_ACCOUNT
              optional: true
        - name: DEPLOY
          value: "{{ .Values.config.app.deploy | default "true" }}"
        - name: REMOTE
          value: "{{ .Values.config.app.remote | default "true" }}"
        - name: AUTO_SUBMIT
          value: "{{ .Values.config.app.autoSubmit | default "" }}"
        - name: IMAGE
          value: "{{ .Values.config.app.image | default "" }}"
        ports:
        - containerPort: 3000
          name: http
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
EOL

cat > ${CHART_PATH}/templates/service.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-rpc
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "${CHART_NAME}.selectorLabels" . | nindent 4 }}
EOL

cat > ${CHART_PATH}/templates/NOTES.txt << EOL
1. Get the application URL by running these commands:
{{- if contains "NodePort" .Values.service.type }}
  export NODE_PORT=\$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "${CHART_NAME}.fullname" . }})
  export NODE_IP=\$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://\$NODE_IP:\$NODE_PORT
{{- else if contains "LoadBalancer" .Values.service.type }}
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
        You can watch the status of by running 'kubectl get --namespace {{ .Release.Namespace }} svc -w {{ include "${CHART_NAME}.fullname" . }}'
  export SERVICE_IP=\$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "${CHART_NAME}.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://\$SERVICE_IP:{{ .Values.service.port }}
{{- else if contains "ClusterIP" .Values.service.type }}
  export POD_NAME=\$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "${CHART_NAME}.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=\$(kubectl get pod --namespace {{ .Release.Namespace }} \$POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward \$POD_NAME 8080:\$CONTAINER_PORT
{{- end }}
EOL

cat > ${CHART_PATH}/Chart.yaml << EOL
apiVersion: v2
name: ${CHART_NAME}
description: A Helm chart for HelloWorld Rollup service
type: application
version: 0.1.0
appVersion: "1.0.0"
EOL

cat > ${CHART_PATH}/.helmignore << EOL
# Patterns to ignore when building packages.
*.tgz
.git
.gitignore
.idea/
*.tmproj
.vscode/
EOL

cat > ${CHART_PATH}/templates/mongodb-deployment.yaml << EOL
{{- if .Values.config.mongodb.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-mongodb
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: {{ include "${CHART_NAME}.fullname" . }}-mongodb
  template:
    metadata:
      labels:
        app: {{ include "${CHART_NAME}.fullname" . }}-mongodb
    spec:
      containers:
      - name: mongodb
        image: "{{ .Values.config.mongodb.image.repository }}:{{ .Values.config.mongodb.image.tag }}"
        ports:
        - containerPort: {{ .Values.config.mongodb.port }}
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
      volumes:
      - name: mongodb-data
        persistentVolumeClaim:
          claimName: {{ include "${CHART_NAME}.fullname" . }}-mongodb-pvc
{{- end }}
EOL

cat > ${CHART_PATH}/templates/redis-deployment.yaml << EOL
{{- if .Values.config.redis.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-redis
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: {{ include "${CHART_NAME}.fullname" . }}-redis
  template:
    metadata:
      labels:
        app: {{ include "${CHART_NAME}.fullname" . }}-redis
    spec:
      containers:
      - name: redis
        image: "{{ .Values.config.redis.image.repository }}:{{ .Values.config.redis.image.tag }}"
        ports:
        - containerPort: {{ .Values.config.redis.port }}
        resources:
          {{- toYaml .Values.config.redis.resources | nindent 10 }}
{{- end }}
EOL

cat > ${CHART_PATH}/templates/merkle-deployment.yaml << EOL
{{- if .Values.config.merkle.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-merkle
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: {{ include "${CHART_NAME}.fullname" . }}-merkle
  template:
    metadata:
      labels:
        app: {{ include "${CHART_NAME}.fullname" . }}-merkle
    spec:
      containers:
      - name: merkle
        image: "{{ .Values.config.merkle.image.repository }}:{{ .Values.config.merkle.image.tag }}"
        command: ["./target/release/csm_service"]
        args: ["--uri", "mongodb://{{ include "${CHART_NAME}.fullname" . }}-mongodb:{{ .Values.config.mongodb.port }}"]
        ports:
        - containerPort: {{ .Values.config.merkle.port }}
        env:
        - name: URI
          value: mongodb://{{ include "${CHART_NAME}.fullname" . }}-mongodb:{{ .Values.config.mongodb.port }}
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
{{- end }}
EOL

cat > ${CHART_PATH}/templates/mongodb-pvc.yaml << EOL
{{- if and .Values.config.mongodb.enabled .Values.config.mongodb.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-mongodb-pvc
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
  annotations:
    "helm.sh/resource-policy": keep
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.config.mongodb.persistence.size }}
  storageClassName: {{ .Values.config.mongodb.persistence.storageClassName }}
{{- end }}
EOL

cat > ${CHART_PATH}/templates/mongodb-service.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-mongodb
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  ports:
    - port: {{ .Values.config.mongodb.port }}
      targetPort: {{ .Values.config.mongodb.port }}
      protocol: TCP
      name: mongodb
  selector:
    app: {{ include "${CHART_NAME}.fullname" . }}-mongodb
EOL

cat > ${CHART_PATH}/templates/merkle-service.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-merkle
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  ports:
    - port: {{ .Values.config.merkle.port }}
      targetPort: {{ .Values.config.merkle.port }}
      protocol: TCP
      name: http
  selector:
    app: {{ include "${CHART_NAME}.fullname" . }}-merkle
EOL

cat > ${CHART_PATH}/templates/redis-service.yaml << EOL
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-redis
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  ports:
    - port: {{ .Values.config.redis.port }}
      targetPort: {{ .Values.config.redis.port }}
      protocol: TCP
      name: redis
  selector:
    app: {{ include "${CHART_NAME}.fullname" . }}-redis
EOL

cat > ${CHART_PATH}/templates/ingress.yaml << EOL
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
  annotations:
    kubernetes.io/ingress.class: nginx
    {{- if .Values.ingress.cors.enabled }}
    nginx.ingress.kubernetes.io/cors-allow-origin: "{{ .Values.ingress.cors.allowOrigins }}"
    nginx.ingress.kubernetes.io/cors-allow-methods: "{{ .Values.ingress.cors.allowMethods }}"
    nginx.ingress.kubernetes.io/cors-allow-headers: "{{ .Values.ingress.cors.allowHeaders }}"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "{{ .Values.ingress.cors.allowCredentials }}"
    nginx.ingress.kubernetes.io/cors-max-age: "{{ .Values.ingress.cors.maxAge }}"
    {{- end }}
    cert-manager.io/cluster-issuer: letsencrypt-prod
    {{- with .Values.ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if .Values.ingress.tls.enabled }}
  tls:
  - hosts:
    - "{{ .Values.ingress.domain.prefix }}.{{ .Release.Namespace }}.{{ .Values.ingress.domain.base }}"
    secretName: "{{ .Release.Name }}-tls"
  {{- end }}
  rules:
  - host: "{{ .Values.ingress.domain.prefix }}.{{ .Release.Namespace }}.{{ .Values.ingress.domain.base }}"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ include "${CHART_NAME}.fullname" . }}-rpc
            port:
              number: {{ .Values.service.port }}
EOL

mkdir -p ts

cat > ts/publish.sh << EOL
#!/bin/bash

# 加载环境变量
if [ -f .env ]; then
  echo "Loading environment variables from .env file"
  source .env
elif [ -f ../.env ]; then
  echo "Loading environment variables from parent directory .env file"
  source ../.env
else
  echo "No .env file found"
fi

node ./node_modules/zkwasm-service-cli/dist/index.js addimage -r "https://rpc.zkwasmhub.com:8090" -p "./node_modules/zkwasm-ts-server/src/application/application_bg.wasm" -u "\${USER_ADDRESS}" -x "\${USER_PRIVATE_ACCOUNT}" -d "Multi User App" -c 22 --auto_submit_network_ids ${CHAIN_ID} -n "${CHART_NAME}" --creator_only_add_prove_task \${CREATOR_ONLY_ADD_PROVE_TASK:-${CREATOR_ONLY_ADD_PROVE_TASK}}
EOL

chmod +x ts/publish.sh

chmod +x scripts/generate-helm.sh

echo "Helm chart generated successfully at ${CHART_PATH}"
echo "Publish script generated at ts/publish.sh"
