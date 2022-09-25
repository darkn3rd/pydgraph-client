# pydgraph-client

This is a demonstration client using the `pydgraph` client to communicate with Dgraph through gRPC.

Joaquin Menchaca (Sep 25, 2022)

## Prerequisites

* Dgraph needs to be deployed through helm with the release name of `dgraph` in the `dgraph` namespace.
  * set `DGRAPH_RELEASE` to change the name of the release.
  * set `DGRAPH_NS` to change the name of the namespace.
* [Docker](https://www.docker.com/) is needed to build and publish the docker image.
* [Helmfile](https://github.com/helmfile/helmfile) is needed to deploy using the `helmfile.yaml`

## Building the Docker image

Set your repository to an appropriate value, add access to Docker as appropriate to access the container registry, and then proceed to make and build the image

Examples:

```bash
# Google Cloud
export DOCKER_REGISTRY="gcr.io/$GCR_PROJECT_ID"
# Azure
export DOCKER_REGISTRY="$AZ_ACR_LOGIN_SERVER"

# Build Image
make build

# Publish Image
make push
```

## Deploy to Kubernetes

```bash
helmfile apply
```

## Running Commands from within the contianer

First, exec into the container:

```bash
export CLIENT_NAMESPACE="pydgraph-client"
PYDGRAPH_POD=$(
  kubectl get pods --namespace $CLIENT_NAMESPACE --output name
)

kubectl exec -ti --container "pydgraph-client" --namespace $CLIENT_NAMESPACE \
  ${PYDGRAPH_POD} -- bash
```

Once in the container, you can run these commands below.  

Note that this assumes that traffic is not encrypted through `HTTPS` or `h2`.  The `--plaintext` instructions the client to use `h2c` (or HTTP/2 in cleartext).

```bash
# test HTTP connection
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/health | jq
curl --silent ${DGRAPH_ALPHA_SERVER}:8080/state | jq

# test gRPC connection
grpcurl -plaintext -proto api.proto \
  ${DGRAPH_ALPHA_SERVER}:9080 \
  api.Dgraph/CheckVersion

python3 load_data.py \
  --plaintext \
  --alpha ${DGRAPH_ALPHA_SERVER}:9080 \
  --files ./sw.nquads.rdf \
  --schema ./sw.schema
```

## Addendum: Accessing the container registry Kubernetes

There's surprising amount of suboptimal strategies online to promote doing this.  These are notes for how to support cloud container registries.

### AKS and ACR

These commands below will create a single resource group for both ACR and AKS. Access to read and list images are automatically added to the kubelet identity, i.e. the managed identity that is used by the Kubernetes worker nodes.

```bash
export AZ_RESOURCE_GROUP="testcluster"
export AZ_CLUSTER_NAME="testcluster"
export AZ_LOCATION="westus2"
export AZ_ACR_NAME="testacr"
export KUBECONFIG="$HOME/.kube/$AZ_LOCATION-$AZ_CLUSTER_NAME.yaml"

# Create shared resource group
az group create --name=${AZ_RESOURCE_GROUP} --location=${AZ_LOCATION}

# Create ACR (Azure Container Registry)
az acr create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_ACR_NAME} \
  --sku Basic

# Create AKS (Azure Kubernetes Service)
az aks create \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --generate-ssh-keys \
  --vm-set-type VirtualMachineScaleSets \
  --node-vm-size ${AZ_VM_SIZE:-"Standard_DS2_v2"} \
  --load-balancer-sku standard \
  --enable-managed-identity \
  --network-plugin ${AZ_NET_PLUGIN:-"kubenet"} \
  --network-policy ${AZ_NET_POLICY:-""} \
  --attach-acr ${AZ_ACR_NAME} \
  --node-count 3 \
  --zones 1 2 3

# setup KUBECONFIG
az aks get-credentials \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --name ${AZ_CLUSTER_NAME} \
  --file ${KUBECONFIG:-"$HOME/.kube/${AZ_CLUSTER_NAME}.yaml"}


# Set AZ_ACR_LOGIN_SERVER
export AZ_ACR_LOGIN_SERVER=$(az acr list \
  --resource-group ${AZ_RESOURCE_GROUP} \
  --query "[?name == \`${AZ_ACR_NAME}\`].loginServer | [0]" \
  --output tsv
)
```

### GKE and GCR

The commands will create a GKE cluster add necessary permissions to access GCR.  Note that GCR is not explicitly created because this uses GCS bucket. Access to read and list images are added to the GSA that is used by the Kubernetes worker nodes.

Commands to create the projects and allow appropriate cloud resources to be created on those projects included as well.

```bash
export GKE_PROJECT_ID="my-gke-project"
export GKE_CLUSTER_NAME="my-gke-cluster"
export GKE_REGION="us-central1"
export GKE_SA_NAME="gke-worker-nodes-sa"
export GKE_SA_EMAIL="$GKE_SA_NAME@${GKE_PROJECT_ID}.iam.gserviceaccount.com"
export GCR_PROJECT_ID="my-gcr-project"
export KUBECONFIG="$HOME/.kube/$REGION-$GKE_CLUSTER_NAME.yaml"
export USE_GKE_GCLOUD_AUTH_PLUGIN="True"
export ClOUD_BILLING_ACCOUNT="<insert-your-billing-account-id-here>"

# create project if needed
# enable billing and APIs for GCR if not done already
gcloud projects create $GCR_PROJECT_ID
gcloud config set project $GCR_PROJECT_ID
gcloud beta billing projects link $GCR_PROJECT_ID \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "containerregistry.googleapis.com" # Enable GCR API

# enable billing and APIs for GKE project if not done already
gcloud projects create $GKE_PROJECT_ID
gcloud config set project $GKE_PROJECT_ID
gcloud beta billing projects link $CLOUD_DNS_PROJECT \
  --billing-account $ClOUD_BILLING_ACCOUNT
gcloud services enable "container.googleapis.com"

# Create GSA using principal of least privilege
ROLES=(
  roles/logging.logWriter
  roles/monitoring.metricWriter
  roles/monitoring.viewer
  roles/stackdriver.resourceMetadata.writer
)

# create worker node GSA
gcloud iam service-accounts create $GKE_SA_NAME \
  --display-name $GKE_SA_NAME --project $GKE_PROJECT_ID

# assign google service account to roles in GKE project
for ROLE in ${ROLES[*]}; do
  gcloud projects add-iam-policy-binding $GKE_PROJECT_ID \
    --member "serviceAccount:$GKE_SA_EMAIL" \
    --role $ROLE
done

# create GKE
gcloud container clusters create $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID --region $GKE_REGION --num-nodes 1 \
  --service-account "$GKE_SA_EMAIL" \
  --workload-pool "$GKE_PROJECT_ID.svc.id.goog"

# setup KUBECONFIG
gcloud container clusters  get-credentials $GKE_CLUSTER_NAME \
  --project $GKE_PROJECT_ID \
  --region $GKE_REGION

# Setup Access to GCR (if cross project)
gsutil iam ch \
  serviceAccount:$GKE_SA_EMAIL:objectViewer \
  gs://artifacts.$GCR_PROJECT_ID.appspot.com

# Enable Docker to push to GCR
gcloud auth configure-docker
```
