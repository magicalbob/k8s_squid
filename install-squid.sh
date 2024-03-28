#!/usr/bin/env bash

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
    if ! kind get clusters 2>&1 | grep -q "kind-uptime-kuma"
    then
      envsubst < kind-config.yaml.template > kind-config.yaml
      kind create cluster --config kind-config.yaml --name kind-uptime-kuma
    fi

    # Make sure create cluster succeeded
    if ! kind get clusters 2>&1 | grep -q "kind-uptime-kuma"
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

# set up squid
kubectl apply -f squid.deployment.yml
kubectl apply -f squid.service.yml

# Wait for pod to be running
until kubectl get pod -n infra | grep 1/1; do
  sleep 5
done
