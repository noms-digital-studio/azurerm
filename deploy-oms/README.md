# Ansible Role: Deploy OMS

Uses Azure resource manager template to deploy within Azure, they are initiated via Ansible role. The following solution are deployed
Creation of Log Analytics and workspace
Add Solution from Gallery or marketplace
Add extended/custom solutions
Feed in Azure activity based on the subscription
Create Custom Dashboard
Create Saved Searches
Create Alerts schedules and email notification

## Requirements

Using the Azure Resource Manager modules requires having Azure Python SDK installed on the host running Ansible. You will need to have == v2.0.0RC5 installed. The simplest way to install the SDK is via pip:

```
$ pip install "azure==2.0.0rc5"
```

Using the Azure Resource Manager modules requires authenticating with the Azure API. we have can choose to use Service Principal Credentials

### Storing Credentials

To pass service principal credentials via the environment, define the following variables:

AZURE_CLIENT_ID
AZURE_SECRET
AZURE_SUBSCRIPTION_ID
AZURE_TENANT

OR

When working in a development environment, it may be desirable to store credentials in a file. The modules will look for credentials in $HOME/.azure/credentials. This file is an ini style file. It will look as follows:

```
[default]

subscription_id=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
client_id=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
secret=xxxxxxxxxxxxxxxxx
tenant=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

```

Also, requires automation account in place with run as access permission, which will be used to deploy Custom solutions

## Role Variables

oms_resourceGroup - Sepcific under which resource group OMS deployment need to be performed
oms_resourceGroupLocation - Specific resource group location

oms_workspaceName - OMS Work space name
oms_location - OMS workspace location, europe region used
oms_serviceTier - service tier pricing model
oms_subscription - Azure subscription id

oms_automationAccount - Automation account name, used to deploy custom solution within OMS
oms_automationAccountLocation - Automation account location
ingestSchedulerGuid - Random GUID should be unique for each automation account e:g:- 6daa6b65-0656-4656-a659-36b26e5a660e
ingestCleanupGuid -  Random GUID should be unique for each automation account e:g:- 65e3630a-f5b6-4643-86e4-c65398b6a364

    GUID can be generated from powershell (New-Guid), or change the example to a different unique

```
alert:
  - name - Display name
    alertName - Alert Name
    query - Search or alert query
    category -  Category name
    description - Alert description
    severity - Alert severity
    recipients - recipients email, where the alert need to be notified
```
### Example

```
alert:
  - name: CPU Utilization
    alertName: CPU_Utilization
    query: (Type=Perf) (ObjectName=Processor) (CounterName=\"% Processor Time\") (InstanceName=_Total) AND CounterValue>80 and TimeGenerated>NOW-60MINUTES
    category: Utilization
    description: Alert if CPU Utilization above 80%
    severity: warning
    recipients: b.arokiadoss@kainos.com","P.Taylor@kainos.com
```

## Example Playbook Execution

Run deploy-oms.yaml which is top level execution for demo, it calls down the role, deploys OMS and configures, along side provisions windows and liunx VMs. Windows password secured using Ansible vault (/group_vars/windows.yaml)

```
ansible-playbook deploy-oms.yaml --ask-vault-pass
```

Enable Custom log preview feature, need to be configured within OMS, as it doesn't support any automation as of yet.

Update the OMS Workspace id and key within group_vars.

Execute the following to configure windows, change type for each server based on the group_vars varaibles used.


```
ansible-playbook server-control-windows.yaml --tags "start,omsagent,omsconfig,windefender" --extra-vars type="oms_windows" --ask-vault-pass
```

Execute the following to configure Linux, change type for each server based on the group_vars varaibles used

```
ansible-playbook server-control.yaml --tags "start,omsagent,clamav,omsconfig" --extra-vars type="oms" --ask-vault-pass
```

## Issues

Storage analytics custom solution deployment can be performed only once, either need to be skipped using skiptag option or need to clear down existing solution, then it deploys fresh

```
ansible-playbook deploy-oms.yaml --skip-tags storageanalytics --ask-vault-pass
```
