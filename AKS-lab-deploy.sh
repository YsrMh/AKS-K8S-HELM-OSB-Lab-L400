#!/bin/bash

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
firstNameNoSpaces = "$(echo -e "${firstName}" | tr -d '[:space:]')"
lastNameNoSpaces = "$(echo -e "${lastName}" | tr -d '[:space:]')"

#Begin deployment
echo Creating resource group...
az group create --name AKS-$firstNameNoSpaces$lastNameNoSpaces --location westeurope

echo Creating AKS cluster...
az aks create --resource-group $firstNameNoSpaces$lastNameNoSpaces --name AKSCluster-$firstNameNoSpaces$lastNameNoSpaces --node-count 1 --generate-ssh-keys

echo Getting credentials...
az aks get-credentials --resource-group $firstNameNoSpaces$lastNameNoSpaces --name AKSCluster-$firstNameNoSpaces$lastNameNoSpaces

echo All done. Type kubectl get nodes to see your cluster

#Now trigger logic app to register their deployment for our tracking