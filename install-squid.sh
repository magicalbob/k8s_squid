#!/usr/bin/env bash

export PRODUCT_NAME="squid"

unset USE_KIND
# Check if kubectl is available in the system
if kubectl 2>/dev/null >/dev/null; then
  # Check if kubectl can communicate with a Kubernetes cluster
  if kubectl get nodes 2>/dev/null >/dev/null; then
    echo "Kubernetes cluster is available. Using existing cluster."
    export USE_KIND=0
  else
    echo "Kubernetes cluster is not available. Creating a Kind cluster..."
    export USE_KIND=X
  fi
else
  echo "kubectl is not installed. Please install kubectl to interact with Kubernetes."
  export USE_KIND=X
fi

if [ "X${USE_KIND}" == "XX" ]; then
    # Make sure cluster exists if Mac
    if ! kind get clusters 2>&1 | grep -q "kind-${PRODUCT_NAME}"
    then
      envsubst < kind-config.yaml.template > kind-config.yaml
      kind create cluster --config kind-config.yaml --name "kind-${PRODUCT_NAME}"
    fi

    # Make sure create cluster succeeded
    if ! kind get clusters 2>&1 | grep -q "kind-${PRODUCT_NAME}"
    then
        echo "Creation of cluster failed. Aborting."
        exit 255
    fi
fi

# add metrics
kubectl apply -f https://dev.ellisbs.co.uk/files/components.yaml

# install local storage
kubectl apply -f  local-storage-class.yml

# create infra namespace, if it doesn't exist
kubectl get ns infra 2> /dev/null
if [ $? -eq 1 ]
then
    kubectl create namespace infra
fi

# sort out persistent volume
if [ "X${USE_KIND}" == "XX" ]; then
  export NODE_NAME=$(kubectl get nodes |grep control-plane|cut -d\  -f1|head -1)
  envsubst < ${PRODUCT_NAME}.pv.kind.template > ${PRODUCT_NAME}.pv.yml
else
  export NODE_NAME=$(kubectl get nodes | grep -v ^NAME|grep -v control-plane|cut -d\  -f1|head -1)
  envsubst < ${PRODUCT_NAME}.pv.linux.template > ${PRODUCT_NAME}.pv.yml
  echo mkdir -p ${PWD}/${PRODUCT_NAME}-data|ssh -o StrictHostKeyChecking=no ${NODE_NAME}
fi
kubectl apply -f "${PRODUCT_NAME}.pv.yml"

# create service account in the infra namespace, if it doesn't exist
kubectl get sa -n infra default 2> /dev/null || kubectl create sa default -n infra

# set up squid
kubectl apply -f "${PRODUCT_NAME}.service.yml"
kubectl apply -f "${PRODUCT_NAME}.deployment.yml"

# Wait for pod to be running
until kubectl get pod -n infra | grep 1/1; do
  sleep 5
done

# Set up port forward
kubectl port-forward service/squid-proxy -n infra --address 0.0.0.0 3128:3128 &
