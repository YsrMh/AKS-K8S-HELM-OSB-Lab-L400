#!/bin/bash
echo Please input your team name.
read teamName

teamName=$teamName$RANDOM
az group create -n AksChallengeTrafficManager -l westeurope
az network traffic-manager profile create -n aksChallenge -g AksChallengeTrafficManager --routing-method Priority --unique-dns-name $teamName
az network traffic-manager endpoint create --profile-name aksChallenge -n Primary -g aksChallengeTrafficManager --type externalEndpoints --target "samofthing.com" --priority 1

teamURL=$teamName'.trafficmanager.net'

#Now trigger logic app to register deployment for tracking
curl -d '{"URL" :"'$teamURL'"}' -H "Content-Type: application/json" -X POST 'https://prod-25.northcentralus.logic.azure.com:443/workflows/5951e14e586c407c9750e2b231760b62/triggers/manual/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=3NbKbrZyTZkfxpdK4MLGAKdoVbLMTMc3Iz71-AobiUI'
