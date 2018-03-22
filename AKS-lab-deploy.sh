!/bin/bash

az provider register -n Microsoft.Network
az provider register -n Microsoft.Storage
az provider register -n Microsoft.Compute
az provider register -n Microsoft.ContainerService

echo Hello, please enter your first name:
read firstName

echo And your surname:
read lastName

echo Thanks $firstName. Setting up your deployment...

#Remove spaces from names to avoid deployment errors
firstNameNoSpaces=$(echo $firstName | tr -d ' ')
lastNameNoSpaces=$(echo $lastName | tr -d ' ')

#Now trigger logic app to register deployment for tracking
curl -d '{"FirstName" :"$firstNameNoSpaces","LastName" :"$lastNameNoSpaces"}' -H "Content-Type: application/json" -X POST 'https://prod-49.westeurope.logic.azure.com:443/workflows/4e254a6051a644e8b5b4c77603d71ca4/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=m4Zf_FLy20zvryNlTBdDD02XpAd9J0gbmO9vNnpRrls'

#Begin deployment
echo Creating resource group...
az group create --name AKS-$firstNameNoSpaces$lastNameNoSpaces --location eastus

echo Creating AKS cluster...
az aks create --resource-group AKS-$firstNameNoSpaces$lastNameNoSpaces --name AKSCluster-$firstNameNoSpaces$lastNameNoSpaces -k "1.9.2" -s Standard_B2s --node-count 2 --generate-ssh-keys

echo Getting credentials...
az aks get-credentials --resource-group AKS-$firstNameNoSpaces$lastNameNoSpaces --name AKSCluster-$firstNameNoSpaces$lastNameNoSpaces

echo All done.
kubectl get nodes
