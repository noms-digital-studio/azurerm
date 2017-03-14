###############################################################################################
# Created By: Joe McGrath (j.mcgrath@kainos.com)
# The purpose of this script is to do the following - 
# 1) Stand up a Resource Group
# 2) Stand up a Keyvault and add relevant secrets
# 3) Prepare the Keyvault for use with Disk Encryption
# 4) Stand up a new IIS environment - 
#     SQL server with encrypted disks, 
#     Jump box, 
#     Storage accounts with encryption, 
#     SQL PAAS, 
#     NSG
# 5) Enable Jump Box logging (this has to be done by Powershell/CLI as its not supported using json for configuration of this
# 6) Encrypt SQL VM disks
#
###############################################################################################

Param(
  [Parameter(Mandatory = $true, 
             HelpMessage="Name of the resource group to which the KeyVault belongs to.  A new resource group with this name will be created if one doesn't exist")]
  [ValidateNotNullOrEmpty()]
  [string]$resourceGroupName,

  [Parameter(Mandatory = $true,
             HelpMessage="Name of the KeyVault in which encryption keys are to be placed. A new vault with this name will be created if one doesn't exist")]
  [ValidateNotNullOrEmpty()]
  [string]$keyVaultName,

  [Parameter(Mandatory = $true,
             HelpMessage="Location of the KeyVault. Important note: Make sure the KeyVault and VMs to be encrypted are in the same region / location.")]
  [ValidateNotNullOrEmpty()]
  [string]$location,

  [Parameter(Mandatory = $true,
             HelpMessage="Name of the AAD application that will be used to write secrets to KeyVault. A new application with this name will be created if one doesn't exist. If this app already exists, pass aadClientSecret parameter to the script")]
  [ValidateNotNullOrEmpty()]
  [string]$aadAppName,

  [Parameter(Mandatory = $true,
             HelpMessage="Client secret of the AAD application that was created earlier")]
  [ValidateNotNullOrEmpty()]
  [secureString]$aadClientSecret,

  [Parameter(Mandatory = $false,
             HelpMessage="Identifier of the Azure subscription to be used. Default subscription will be used if not specified.")]
  [ValidateNotNullOrEmpty()]
  [string]$subscriptionId,

  [Parameter(Mandatory = $false,
             HelpMessage="Name of optional key encryption key in KeyVault. A new key with this name will be created if one doesn't exist")]
  [ValidateNotNullOrEmpty()]
  [string]$keyEncryptionKeyName

)

###############################################################################################
# Log-in to Azure and select appropriate subscription. 
###############################################################################################
  

    Write-Host 'Please log into Azure now' -foregroundcolor Green;
    Login-AzureRmAccount -ErrorAction "Stop" 1> $null;

    if($subscriptionId)
    {
        Select-AzureRmSubscription -SubscriptionId $subscriptionId;
    }
    $userObjectID = Get-AzureRmaduser | Select-Object -ExpandProperty Id 
    $userObjectID = $userObjectID.Guid
    Write-Host "`t object Id: $userObjectID" -foregroundcolor Green;
###############################################################################################
# Section1:  Create Resource Group. 
###############################################################################################

New-AzureRmResourceGroup -Name $resourceGroupName -Location $Location 

###############################################################################################
# Section2:  Create KeyVault and add secrets. 
###############################################################################################

New-AzureRmResourceGroupDeployment -name iisvaultdeploy -ResourceGroupName $resourceGroupName -TemplateFile .\templates\iisvault.json -TemplateParameterFile .\parameters\iisvault.parameters.json -keyVaultName $keyVaultName -objectId $userObjectID -aadUserPassword $aadClientSecret


###############################################################################################
# Section3:  Create AAD Application user and add to keyvault in preparation for disk encryption. 
###############################################################################################

. .\AzureDiskEncryptionPreRequisiteSetup.ps1 -resourceGroupName $resourceGroupName -location $Location -keyVaultName $keyVaultName -aadAppName $aadAppName -aadClientSecret $aadClientSecret


###############################################################################################
# Section5:  Instantiate environment 
###############################################################################################
Write-Host "Building the Main IIS environment" -foregroundcolor Green;
#Retrieve secrets from vault in preparation to pass through in to template

$adminpassword = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'iisadmin').SecretValue) -AsPlainText -force
$sqladminpassword = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'sql-iis-production-admin').SecretValue) -AsPlainText -force
$passsqlpassword = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'sql-paas-iis-production-admin').SecretValue) -AsPlainText -force
$sshkey = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'jumpbox-iis-public-key-production').SecretValue) -AsPlainText -force
$jumpboxadmin = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'jumpadmin').SecretValue) -AsPlainText -force
$aasClientSecret = ConvertTo-SecureString ((Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name 'aadUserPassword').SecretValue) -AsPlainText -force
#New-AzureRmResourceGroupDeployment -name iistestdeploy -ResourceGroupName $RGName -TemplateFile .\templates\iisenvironment.json -TemplateParameterFile .\parameters$parameterfileenvironment -aadClientID $aadClientIID -aadClientSecret $aadClientSecret -keyVaultResourceId $keyVaultResourceId

New-AzureRmResourceGroupDeployment -name iistestdeploy -ResourceGroupName $resourceGroupName -TemplateFile .\templates\iisenvironment.json -TemplateParameterFile .\parameters\iisenvironment.parameters.json -adminpassword $adminpassword -jumpboxadminpassword $jumpboxadmin -sqldb-admin-password $sqladminpassword -paas-sqlAuthenticationPassword $passsqlpassword -objectId $userObjectID


###############################################################################################
# Section5: Enable Jump Box Diagnostic logging 
###############################################################################################



###############################################################################################
# Section6:  Encrypt SQL Server disks 
###############################################################################################
    Write-Host "Preparing to encrypt SQL server disks - these are the values that we will be using " -foregroundcolor Green;
    Write-Host "`t aadClientID: $aadClientID" -foregroundcolor Green;
    Write-Host "`t aadClientSecret: $aadClientSecret" -foregroundcolor Green;
    Write-Host "`t diskEncryptionKeyVaultUrl: $diskEncryptionKeyVaultUrl" -foregroundcolor Green;
    Write-Host "`t keyVaultResourceId: $keyVaultResourceId" -foregroundcolor Green;
    if($keyEncryptionKeyName)
    {
        Write-Host "`t keyEncryptionKeyURL: $keyEncryptionKeyUrl" -foregroundcolor Green;
    }
$sqlvmName = 'sqliisprod'

Set-AzureRmVMDiskEncryptionExtension -ResourceGroupName $resourceGroupName -VMName $sqlvmName -aadClientID $aadClientID -AadClientSecret $aadClientSecret -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl -DiskEncryptionKeyVaultId $keyVaultResourceId

