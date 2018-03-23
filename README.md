# Azure Container Service (AKS) - Kubernetes Wordpress Lab.  Level 400

## Contents

### Campaign mode: Deploying Wordpress in Containers
1. Using Azure Container Service (AKS)
1. Working with OSBA and Helm
1. Deploying Wordpress & Managed MySQL
1. Setting up Persistent Volumes (Azure Disks & Files)

### Then "Choose your own adventure"... 

#### Path 1: Explore and configure Wordpress
1. Install plug-ins
1. Set up back-up, telemetry, caching 

#### Path 2: Test your app's performance
1. Availability tests
1. VSTS Load testing & Kubernetes scaling

#### Path 3: Make your app highly available
1. Setting up a Traffic Manager profile
1. Configuring endpoints
1. Testing different routing methods

---

##Prerequisites

[If you want to use your local CLI for this lab instead of the CLoud Shell, view the pre-requisites here.](https://github.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/blob/master/Prerequisites.md)

---

#Let's begin

## Cluster Setup (SKIP if you did this earlier this week when instructed)

You should have already done this using the script we provided via email. But not to worry, if you haven't, just run the script below. Bear in mind that this can usually take around 10-15 minutes.
 
Run the following two commands in the Azure Bash Cloud Shell:

```console
curl -o ~/clouddrive/aks-create.sh https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/AKS-lab-deploy.sh
  
sh ~/clouddrive/aks-create.sh
``` 

## Configure your Azure account

First let's identify your Azure subscription and save it for use later on in the quickstart.

1. Run `az login` and follow the instructions in the command output to authorize `az` to use your account
1. List your Azure subscriptions:
    ```console
    az account list -o table
    ```
1. Copy your subscription ID and save it in an environment variable:

    **Bash**
    ```console
    export AZURE_SUBSCRIPTION_ID="<SubscriptionId>"
    ```

    **PowerShell**
    ```console
    $env:AZURE_SUBSCRIPTION_ID = "<SubscriptionId>"
    ```

### Create a service principal

This creates an identity for Open Service Broker for Azure to use when provisioning
resources on your account on behalf of Kubernetes.

1. Create a service principal with RBAC enabled for the quickstart:
    ```console
    az ad sp create-for-rbac --name osba-quickstart -o table
    ```
>Note: If it says the name already exists, choose another name.

![Azure Service Principal](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/images/ad_sp.PNG)

1. Save the values from the command output in environment variables:

    **Bash**
    ```console
    export AZURE_TENANT_ID=<Tenant>
    export AZURE_CLIENT_ID=<AppId>
    export AZURE_CLIENT_SECRET=<Password>
    ```

    **PowerShell**
    ```console
    $env:AZURE_TENANT_ID = "<Tenant>"
    $env:AZURE_CLIENT_ID = "<AppId>"
    $env:AZURE_CLIENT_SECRET = "<Password>"
    ```

### Obtain the credentials for your AKS Cluster

1. This will allow other command dependencies to execute the relevant commands into your Kubernetes cluster.
    ```console
    az aks get-credentials -n [NAME-OF-YOUR-AKS-CLUSTER] -g [NAME-OF-YOUR-AKS-RESOURCE-GROUP]
    ```

### Installing packages ("charts") with Helm

Helm is a tool that streamlines installing and managing Kubernetes applications. Think of it like apt/yum/homebrew for Kubernetes.

Helm has two parts: a client (helm) and a server (tiller)
* Tiller runs inside of your Kubernetes cluster, and manages releases (installations) of your charts.
* Helm runs on your laptop, CI/CD, or wherever you want it to run.

Charts are Helm packages that contain at least two things:
* A description of the package (Chart.yaml)
* One or more templates, which contain Kubernetes manifest files

Charts can be stored on disk, or fetched from remote chart repositories (like Debian or RedHat packages)

Common Helm commands:

* `helm init`: installer Tiller to your cluster
* `helm repo add`: add a remote repo
* `helm search`: search for charts
* `helm fetch`: download a chart to your local directory to view
* `helm install`: upload the chart to Kubernetes cluster
* `helm list`: list releases of charts

1. Before we can use Helm to install applications such as Service Catalog (which we'll cover in the next step) and
    WordPress on the cluster, we first need to prepare the cluster to work with Helm:
    ```console
    helm init
    ```

---
## Deploy Vanilla WordPress and MariaDB (local instance of MariaDB in a container)

**Bash**

    helm install --name my-release \
    --set wordpressUsername=admin,wordpressPassword=password,mariadb.mariadbRootPassword=secretpassword \
    stable/wordpress


That's it! Run the following command to find out when your service is ready:

   **Bash**

    kubectl get deploy my-release-wordpress --namespace default -w

>Note: The -w parameter watches the new output from the kubectl get command. If you would like to exit this mode, press CLTR+C.

When ready, run the following command to find out the external ip for your wordpress service:

   **Bash**

    kubectl get svc --namespace default my-release-wordpress

Now, type http://externalip/admin into your browser, replacing 'externalip' with the ip you just retrieved, and log in with the username and password you set earlier. 

Feel free at this point to 'choose your next adventure' or try deploying Wordpress via one of the other methods below.

---

## Deploy WordPress, Azure SQL DB using Helm and OSBA with persistent storage (Azure Disk or Azure Files)

### Use Helm to install the Open Service Broker for Azure for easy set up of our database

WordPress requires a back-end MySQL database, and if we want this to be in Azure, normally we would create a database in the Azure portal, and then manually configure the connection information. 

Thankfully there's an easier way. In Kubernetes we have something handy called the Service Catalog.

>Service Catalog is an extension API that enables applications running in Kubernetes clusters to easily use external managed software offerings, such as a datastore service offered by a cloud provider.
>It provides a way to list, provision, and bind with external Managed Services from Service Brokers without needing detailed knowledge about how those services are created or managed.

The broker for Azure is aptly called the Online Service Broker for Azure, or OSBA.

To get started with OSBA, we need to first install the Kubernetes Service Catalog on our cluster to allow us to communicate with Azure's service broker.

1. Deploy Service Catalog on the cluster:

    **Bash**
    ```console
    helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com
    helm install svc-cat/catalog --name catalog --namespace catalog \
       --set rbacEnable=false \
       --set apiserver.storage.etcd.persistence.enabled=true
    ```

    **PowerShell**
    ```console
    helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com
    helm install svc-cat/catalog --name catalog --namespace catalog `
   --set rbacEnable=false `
   --set apiserver.storage.etcd.persistence.enabled=true
   ```
    Note: the AKS preview does not _currently_ support RBAC, so you must disable RBAC as shown above. The command above also enables persistence for the embedded etcd used by Service Catalog. Using this flag will create a persistent volume for the etcd instance to use. Enabling the persistent volume is recommended for evaluation of Service Catalog because it allows you to restart Service Catalog without data loss. For production use, we recommend a dedicated etcd cluster with appropriate persistent storage and backup.

    Afterwards, run this command to verify the catalog pods are in Running state, before moving onto the next command. Otherwise, you will encounter timeout errors.
    ```console
    $ kubectl get pods --namespace catalog -w
    NAME                                                     READY     STATUS    RESTARTS   AGE
    po/catalog-catalog-apiserver-5999465555-9hgwm            2/2       Running   4          9d
    po/catalog-catalog-controller-manager-554c758786-f8qvc   1/1       Running   11         9d
    ```
    >**Note: the -w parameter will watch the console for updates. You do not need to keep on re-running the commad. If you would like to exit this mode, press CLTR+C.**


1. Deploy Open Service Broker for Azure on the cluster:

    **Bash**
    ```console
    helm repo add azure https://kubernetescharts.blob.core.windows.net/azure
    helm install azure/open-service-broker-azure --name osba --namespace osba \
      --set azure.subscriptionId=$AZURE_SUBSCRIPTION_ID \
      --set azure.tenantId=$AZURE_TENANT_ID \
      --set azure.clientId=$AZURE_CLIENT_ID \
      --set azure.clientSecret=$AZURE_CLIENT_SECRET
    ```

    **PowerShell**
    ```console
    helm repo add azure https://kubernetescharts.blob.core.windows.net/azure
    helm install azure/open-service-broker-azure --name osba --namespace osba `
      --set azure.subscriptionId=$env:AZURE_SUBSCRIPTION_ID `
      --set azure.tenantId=$env:AZURE_TENANT_ID `
      --set azure.clientId=$env:AZURE_CLIENT_ID `
      --set azure.clientSecret=$env:AZURE_CLIENT_SECRET
    ```


1. Check on the status of everything that we have installed by running the
    following command and checking that every pod is in the `Running` state.
    You may need to wait a few minutes, rerunning the command until all of the
    resources are ready.
    ```console

    $ kubectl get pods --namespace osba -w
    NAME                                           READY     STATUS    RESTARTS   AGE
    po/osba-azure-service-broker-8495bff484-7ggj6   1/1       Running   0          9d
    po/osba-redis-5b44fc9779-hgnck                  1/1       Running   0          9d
    ```

1. Now that we have a cluster with Open Service Broker for Azure, we can deploy

Now that we have a cluster with Open Service Broker for Azure, we can deploy
WordPress to Kubernetes and OSBA will handle provisioning an Azure Database for MySQL
and binding it to our WordPress installation.

### Option 1: Install WordPress using Azure Disks as persistent storage
```console
helm install azure/wordpress --name osba-quickstart --namespace osba-quickstart
```

### Option 2: Install WordPress using Azure Files as persistent storage

1. Create an Azure Storage account. Although AKS can dynamically provision Azure disks, and Azure files within a storage account, you still need to provision an Azure storage account. Furthermore, Azure disks already has a Storage Class provisioned with AKS, but not for Azure Files.

>**Note:** The name of your resource group will have the prefix of MC_XXX, use this one which has all of Kubernetes Azure resources provisioned in it. Using the resource group which only has your cluster resource in it will fail (i.e do not choose the resource group which only shows one resoure for your K8s cluster).

**Bash**
```console
storageAccountName=$(az storage account create --resource-group [NAME-OF-RESOURCE-GROUP] --name aksazurestorageacc$RANDOM --location [LOCATION] --sku Standard_LRS --query name | sed 's/\"//g')
```

**PowerShell**
```console
$storageAccountName = $(az storage account create --resource-group [NAME-OF-RESOURCE-GROUP] --name aksazurestorageacc$(Get-Random -Maximum 8000 -Minimum 400) --location [LOCATION]  --sku Standard_LRS --query name) -replace '"',""
```
**Bash or PowerShell**
```console
echo 'kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefiles
  labels:
     kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0775
  - uid=1
  - gid=1
parameters:
  storageAccount: '$storageAccountName > azurefilestorageclass.yaml

  kubectl create -f azurefilestorageclass.yaml
```

```console
helm install --name osba-quickstart azure/wordpress --set persistence.storageClass=azurefiles --set persistence.accessMode=ReadWriteMany --set livenessProbe.initialDelaySeconds=850 --set readinessProbe.initialDelaySeconds=920 --namespace osba-quickstart
```

> **NOTE**: Both of the options above, use Azure Storage mounted as Persistent Volumes (PV) in Kubernetes to persist WordPress data and share them across multiple containers i.e if you re-created a container without a PV, the data within the container is lost. Thus, WP media files need to be perserved. The issue with Azure Disks, is you can only mount them to one given cluster node at any given time. In other words, you cannot scale your application across nodes as your pods on the other nodes will not be able to moun the drives. However, Azure files supports being mounted to multiple nodes.

### Monitoring WordPress installation 

>**Note**: When deploying the helm package with Azure Files, it can take around 18 minutes before the container is ready (probably due to the time it takes to provision Azure MySQL, Azure File Share and setup/copy the appropiate files). With Azure Disk, it takes around 12 minutes. In the meantime, feel free to have a glance at the next steps.

1. Use the following command to tell when WordPress is ready:

    ```console
    $ kubectl get deploy osba-quickstart-wordpress -n osba-quickstart -w

    NAME                        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
    osba-quickstart-wordpress   1         1         1            0           1m
    ...
    osba-quickstart-wordpress   1         1         1            1           18m
    ```

Note:  While provisioning WordPress and Azure Database for MySQL using Helm, all of the required resources are created in Kubernetes at the same time. As a result of these requests, Service Catalog will create a secret containing the the binding credentials for the database. This secret will not be created until after the Azure Database for MySQL is created, however. The WordPress container will depend on this secret being created before the container will fully start. Kubernetes and Service Catalog both employ a retry backoff, so you may need to wait several minutes for everything to be fully provisioned.

### Navigating to WordPress

1. Obtain the LoadBalancer IP Address from your WordPress Kubernetes Service

```console
kubectl get svc --namespace osba-quickstart -w osba-quickstart-wordpress
```

1. Open a web browser and navigate to the IP address.

![Wordpress in a browser](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/images/wp-browser.PNG)

### Login to WordPress

1. Run the following command to open obtain the IP address of WordPress:
    ```console
    kubectl get svc --namespace osba-quickstart osba-quickstart-wordpress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    ```
Now navigate to the above IP address and you should see your WP homepage. Well done!

1. To retrieve the password, run this command:
    
    **Bash**

    ```console
    kubectl get secret osba-quickstart-wordpress -n osba-quickstart -o jsonpath="{.data.wordpress-password}" | base64 --decode
    ```

    **PowerShell**

    ```console
    $password = kubectl get secret osba-quickstart-wordpress -n osba-quickstart -o jsonpath="{.data.wordpress-password}"
 
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($password))
     ```

1. Login using the username `user` and the password you just retrieved

## Uninstall WordPress

If you want to uninstall WordPress that was installed by Helm (e.g. you decided to install a different WordPress deployment), please scroll down to the section "Cleaning up".

## Well done, you've completed Campaign Mode. 

Once you are online and happy with the Wordpress deployment service you have chosen, please add a DNS entry to your static ip address found within your Kubernetes cluster (Resource Group MC_XXX) and inform the proctors of your Traffic Manager's URL.

---
# Now it's time to choose your own adventure...

Now that you've got your Wordpress site up and running, there are several paths you can take to optimise it, make it highly available, and boost its performance. It's up to you which of these paths you take, and in what order, depending on what interests you. 

Choose wisely...

---

# Path 1: Explore and configure Wordpress
Wordpress has over 50,000 plugins available in their marketplace that enable you to expand and customise your site in a number of ways.  Simply navigate to Plugins on the left menu, and choose 'Add New'.  Below are some suggestions for getting started - have fun!

![Install Plugins](https://wordpressfilestore.blob.core.windows.net/images/installplugins.png)

 ##Caching / Static Site Generators:

#Simply Static

[Simply Static](https://en-gb.wordpress.org/plugins/simply-static/) is a static site generator for WordPress that helps you create a static site that you can serve separately from your WordPress installation. This provides a couple benefits. One, this allows you to keep WordPress in a secure location that no one can access but you. Two, your static site is going to be really, really fast.


#WP Super Cache


[WP Super Cache](https://en-gb.wordpress.org/plugins/wp-super-cache/) generates static html files from your dynamic WordPress blog. After a html file is generated your webserver will serve that file instead of processing the comparatively heavier and more expensive WordPress PHP scripts.

The static html files will be served to the vast majority of your users:

*Users who are not logged in.
*Users who have not left a comment on your blog.
*Or users who have not viewed a password protected post.

##Telemetry

The [Application Insights](https://en-gb.wordpress.org/plugins/application-insights/) plugin enables you to pass it your App Insights instrumentation key (available in the Azure portal) to gain rich insights and telemetry. 

![Application Insights](https://wordpressfilestore.blob.core.windows.net/images/appinsights.png)

##Back ups

The [All-in One WP Migration](https://en-gb.wordpress.org/plugins/all-in-one-wp-migration/) plugin exports your WordPress website including the database, media files, plugins and themes with no technical knowledge required. Upload your site to a different location with a drag and drop in to WordPress.

![Backups](https://wordpressfilestore.blob.core.windows.net/images/export.png)


---

# Path 2: Test your app's performance
1. Availability tests
1. VSTS Load testing & Kubernetes scaling

---

# Path 3: Make your app highly available

In this path we'll cover making your site highly available, by setting up a secondary site and using Traffic Manager to route requests between them in the best way.

## Create a secondary Wordpress site

With our availability hats on, despite the magic of Kubernetes self-healing etc., we should have a secondary site to failover to should the worst happen... 

![meteor strike](http://3.bp.blogspot.com/-hqrTHot4irc/UmVJf7lp_2I/AAAAAAAAl7s/ttFvcr0ba30/s1600/meteor-strike.jpg)

How you go about doing this is up to you. All you need for the next step is a Public IP & DNS address that you'll provide in Traffic Manager as a secondary endpoint.

Here's a couple of ideas to get the ball rolling:

1. Repeat the previous steps to create another Kubernetes cluster with Wordpress installed, then point it at the same file storage as your previous cluster. However, consider what may happen if that region's Azure Files goes down. Is there any way to protect against this perhaps...? 

2. Export a static site from Wordpress (you can use the Static Site generator Wordpress plug-in for this, located [here](https://wordpress.org/plugins/simply-static/)) and host it on App Service. You could also then automate it's deployment using some clever PowerShell, something like this:

    ```PowerShell
    $sitename=""
    $username = ""
    $password = ""
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
    $apiUrl = "https://$sitename.scm.azurewebsites.net/api/zip/site/wwwroot"
    $filePath = "C:\SimplyStatic\simply-static-1-1513630015.zip"
    Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method PUT -InFile $filePath -ContentType "multipart/form-data" | Out-Null
Make sure you think about regional failures etc. when doing this, and how you can protect against it.

Once you've figured this out, it's time to set up our Traffic Manager.

## Setting up a Traffic Manager profile

Now that we've got primary and secondary sites up and running, we need to make sure that incoming requests are directed between them appropriately for high availability. That's where Traffic Manager comes in. 

We'll use it to create DNS-based routing to our back-end endpoints, and Traffic Manager will then monitor these so that should one of our sites go down, traffic will be routed to the other.

Let's start by setting up a Traffic Profile for our sites. 

Enter the following Azure CLI command into your terminal to provision this, adding in a unique name and specifying the resource group you've already created (which should be "AKS-YourfirstnameYourlastname"), as well as a unique DNS name (for example "JamesG-AKS-Wordpress" the .trafficmanager.net suffix will be added automatically during deployment):

```console
az network traffic-manager profile create -n [YOUR-TRAFFIC-MGR-NAME] -g [YOUR-RESOURCE-GROUP] --routing-method Priority --unique-dns-name [UNIQUE-DNS-NAME]
```

![TrafficManagerDeploy](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/images/TrafficManagerDeploy.PNG)

Notice we've specified Priority as the routing method. This determines how Traffic Manager will route the traffic to our endpoints. The four main options here are as follows:

- `Priority`: Select Priority when you want to use a primary service endpoint for all traffic, and provide backups in case the primary or the backup endpoints are unavailable.

- `Weighted`: Select Weighted when you want to distribute traffic across a set of endpoints, either evenly or according to weights, which you define.

- `Performance`: Select Performance when you have endpoints in different geographic locations and you want end users to use the "closest" endpoint in terms of the lowest network latency.

- `Geographic`: Select Geographic so that users are directed to specific endpoints (Azure, External, or Nested) based on which geographic location their DNS query originates from. This empowers Traffic Manager customers to enable scenarios where knowing a user’s geographic region and routing them based on that is important. Examples include complying with data sovereignty mandates, localization of content & user experience and measuring traffic from different regions.

We'll leave this as Priority for now, which will send the user to the endpoint we define as the priority, unless the health probing determines it's down, in which case the secondary will come into play.

## Setting up Traffic Manager endpoints

Next, we need to set up the endpoints that Traffic Manager will probe and direct to.   

1. Before we can do this, because TM is DNS-based, we need to make sure we have Fully-Qualified Domain Names (FQDNs) for our apps and not just IP addresses. For the primary site, you need to configure DNS for the Public IP address that was created as part of your cluster. You can do this in the portal - and I'll leave you to figure out how! 

    Depending on your choice of secondary site, you may or may not have DNS enabled on your Public IP for that site. When you go to the next step Traffic Manager will handily tell you if not so you can go and rectify it.

    If you've used App Service you don't need to worry as this is natively supported as an Azure endpoint.  

2. Now that that's sorted, we can add the endpoints to Traffic Manager. We'll head to the portal for this as it means we won't have to dig around for the resource URIs to add them via the CLI. Plus it'll be nice to have a break from staring at a terminal.

    Open up the portal and search for your Traffic Manager in the search bar. Once you've selected it, click on Endpoints in the left-hand menu, then click `Add`.

    Fill in the parameters like so:

    1. `Type`: Azure Endpoint

    2. `Name`: call this something like 'Cluster1"

    3. `Target resource type`: Public IP address

    4. `Target resource`: from the list, find one of your endpoints, which will be named 'kubernetes-' followed by a random string of numbers ###unless this changes

    5. `Priority`: leave this as "1"

    Click `OK`

3. That's one added. Now repeat the above steps to add your secondary endpoint, changing `Priority` to "2" - if you've used App Service you'll also see that as an option instead of Public IP address, so you can use that instead.

    Once you've done this, Traffic Manager will begin to probe your endpoints, and you'll see the 'Monitor Status' attribute change to Online after a couple of minutes (as long as yur cluster is up and running).

And that's it. Now, if you head to the Traffic Manager URL you set up (you can find this on the Overview pane) and head to it in a new tab, you should be greeted by your blog. In the backend, Traffic Manager has checked if your primary endpoint up and running, then routed you through to it if so.

## Testing Traffic Manager

1. To assess how TM is routing our requests, we can use `nslookup`. Enter the following in your terminal, placing in your own Traffic Manager URL:

    ```console
    nslookup [YOUR-TM-NAME].trafficmanager.net
    ```

    You should get back the IP address that you're being directed to. 
    
2. Repeat this a couple more times and you should find that this remains the same, because the primary endpoint is still operational.

    ![nslookup1](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/images/nslookup1.PNG)

3. Now, let's modify our TM profile to explore this. Head back to the Azure portal, and in your Traffic Manager blade, click on `Configuration`. 

4. Change the Routing method from Priority to Weighted, then change the DNS Time to Live (TTL) to "0", then click `Save`.

5. Now let's test again. Run the nslookup command a few times and see which IP addresses get returned (you may need to run a `ipconfig /flushdns` first). 

    You should find that it alternates between the two endpoints. This is because as we haven't specified the individual weighting for our endpoints, they're both set to '1' - meaning that they have equal weighting and thus should recieve an equal amount of our requests.

    ![nslookup2](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L200/master/images/nslookup2.PNG)

It's worth noting here that we can view how all of the various requests are being handled at a global scale in a nice visual output called Traffic View. It takes approximately 24 hours after turning this on however before this starts yielding an output, so something for you to explore after this lab!

Now that you're armed with this knowledge, set up your endpoints using the optimal routing method for the availability of your site - taking into consideration whether you've globally dispersed the endpoints and how you want failover to occur.

---

# Cleaning up

## Uninstall WordPress

Using Helm to uninstall the `osba-quickstart` release will delete all resources
associated with the release, including the Azure Database for MySQL instance.

```console
helm delete osba-quickstart --purge
```

Since deprovisioning occurs asynchronously, the corresponding `serviceinstance`
resource will not be fully deleted until that process is complete. When the
following command returns no resources, deprovisioning is complete:

```console
$ kubectl get serviceinstances -n osba-quickstart
No resources found.
```

## Optional: Further Cleanup

At this point, the Azure Database of MySQL instance should have been fully deprovisioned.
In the unlikely event that anything has gone wrong, to ensure that you are not
billed for idle resources, you can delete the Azure resource group that
contained the database. In the case of the WordPress chart, Azure Database for MySQL was
provisioned in a resource group whose name matches the Kubernetes namespace into
which WordPress was deployed.

```console
az group delete --name osba-quickstart --yes --no-wait
```

To remove the service principal:

```console
az ad sp delete --id http://osba-quickstart
```

To tear down the AKS cluster:

```console
az aks delete -resource-group [RESOURCE-GROUP-NAME] --name [NAME-OF-AKS-CLUSTER] --no-wait
```

## Next Steps

Our AKS managed Kubernetes cluster communicated with Azure via OSBA, provisioned an Azure Database for
MySQL instance, and bound our WordPress installation to that new database.

With OSBA _any_ cluster can rely on Azure to provide all those pesky "as a service"
goodies that make life easier.

Now that you have a cluster with OSBA, adding more applications is quick. Try out another to see for yourself:

* [Concourse CI](https://github.com/Azure/helm-charts/blob/master/concourse)
* [phpBB](https://github.com/Azure/helm-charts/blob/master/phpbb)

All of our OSBA-enabled helm charts are available in the [Azure/helm-charts](https://github.com/Azure/helm-charts)
repository.

## Contributing

Do you have an application in mind that you'd like to use with OSBA? We'd love to
have it! Learn how to [contribute a new chart](https://github.com/Azure/helm-charts#creating-a-new-chart)
to our helm repository.
