#!/bin/bash

#Register user's subscription for resource providers needed for AKS preview
az provider register -n Microsoft.Network
az provider register -n Microsoft.Storage
az provider register -n Microsoft.Compute
az provider register -n Microsoft.ContainerService

echo Hello, and welcome to the War of the WordPress challenge. Please enter your Team Name:

read teamNameRaw

echo Thanks $teamNameRaw. Setting up your deployment...

#Remove spaces from name to avoid deployment errors
teamName=$(echo $teamNameRaw | tr -d ' ')

#Now trigger logic app to register deployment for tracking
curl -d '{"TeamName" :"$teamName","URL" :"warofthewordpress-$teamName"}' -H "Content-Type: application/json" -X POST 'https://prod-20.uksouth.logic.azure.com:443/workflows/326b67ac3ffc4195bd2def1248531a4e/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=SjCIrceqhA_6lU8ACnXm8h75XbVPAkW50w6wPOZvU7w'

#Begin deployment
echo Creating resource group...
az group create --name WarOfTheWordPress-$teamName --location eastus

echo Creating AKS cluster (takes a while)...
az aks create --resource-group WarOfTheWordPress-$teamName --name AKSCluster-WarOfTheWordPress-$teamName -k "1.9.2" -s Standard_B2s --node-count 2 --generate-ssh-keys

echo Creating Traffic Manager...
az network traffic-manager profile create -n aksChallenge -g WarOfTheWordPress-$teamName --routing-method Priority --unique-dns-name warofthewordpress-$teamName
az network traffic-manager endpoint create --profile-name WarOfTheWordPress -n Primary -g WarOfTheWordPress-$teamName --type externalEndpoints --target "microsoft.com" --priority 1

echo Getting credentials...
az aks get-credentials --resource-group WarOfTheWordPress-$teamName --name AKSCluster-$teamName

echo All done and good to go. Good luck $teamNameRaw 
kubectl get nodes
