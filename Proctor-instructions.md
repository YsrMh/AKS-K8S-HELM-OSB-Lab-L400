# Running War of the WordPress
## Instructions for proctors

### Setting up the teams

1. Depending on how many attendees you're expecting, we recommend team sizes of 3-6 people
2. Each team should have a nominated Team Lead, who will be responsible for doing the pre-requisite set-up of the AKS Cluster (running the Bash script provided in the lab instructions)
3. They will be required to enter a Team Name for the teams as a parameter for the set-up script

### Monitoring the Availability and Performance of each site

The Bash script that each team runs to set up their AKS cluster and Traffic Manager in advance of the competition calls a Logic App endpoint as it deploys the resources. 
This provides the team name that they entered (which the script suffixes with a random string then TrafficManager.net to set the endpoint for their WordPress site) which is where you will direct your testing towards.
You will need to follow the steps below to set up your own Logic App to record this, so you can then set up testing in advance of the lab:

1. Go into the Azure portal and create a new Logic App - using the 'HTTP request' trigger as your template
2. Copy this code into the Request JSON Body Schema: 
  ```
  {
      "type": "object",
      "properties": {
          "TeamName": {
              "type": "string"
          },
          "URL": {
              "type": "string"
          }
      }
  }</code>
  ```
  3. Add a second step that posts the TeamName and URL dynamic parameters to a location of your choice so you can view all of the Traffic Manager endpoints. In the example below I used the Excel Connector and also posted a message in Teams:
  
  ![LogicAppSetup](https://raw.githubusercontent.com/samaea/AKS-K8S-HELM-OSB-Lab-L400/master/images/LogicAppSetup.PNG)
  
  4. Hit 'Save' which will generate a URL in the HTTP Trigger for you to use. Copy this to your clipboard.
  5. Fork this GutHub repo into your own GutHub account and edit the provisioning script (called AKS-lab-deploy.sh) to insert the Logic App URL you've got, and commit to master.
  6. Test your Logic App works by doing a test run - run the commands found at the start of the lab instructions (README.md) in your Bash Cloud Shell, entering a dummy team name. Should all go well, your Logic App will be called and your 
  dummy Traffic Manager URL will appear in your tracking system.
  
  If you choose to send out an email before the day with instructions on running the provisioning script (it can take up to 20 minutes so its a good idea), once you've had everyone's responses and their DNS names have appeared for each team,
  you can set up your availability and load testing tools.
  
  We'll leave this to you how you want to do this, but here are some suggestions:
  1. Perform load testing once per hour on each site, with 500 users - stepping up from 0 in 50 user incremements every 1 minute for 10 minutes. [Visual Studio Team Services](https://www.visualstudio.com/team-services/cloud-load-testing/) is a great choice for this.
  2. Perform availability testing from the offset, which will mean people will be more incentivised to get their sites up and running quicker and keep them available while making changes like a production website. [Application Insights](https://docs.microsoft.com/en-us/azure/application-insights/app-insights-monitor-web-app-availability)
  has a great URL ping test you can use; however the minimum interval for each ping is 5 minutes. If you want less than this, we can recommend [Monitis](https://dashboard.monitis.com) as a great alternative with 1 minute ping intervals.
  
### The rest is up to you!

We've designed this to be a good intro to operating live services through Kubernetes on Azure, but to make this better for future iterations, we'd really appreciate your feedback, and please feel free to modify the lab as you see fit and 
submit a pull request on our repo. This is how all great open source labs are built - by a great community!
  
