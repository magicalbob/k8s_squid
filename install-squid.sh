# create infra namespace, if it doesn't exist
kubectl get ns infra 2> /dev/null
if [ $? -eq 1 ]
then
    kubectl create namespace infra
fi

# set up squid
kubectl apply -f squid.deployment.yml
kubectl apply -f squid.networkpolicy.yml
kubectl apply -f squid.service.yml

