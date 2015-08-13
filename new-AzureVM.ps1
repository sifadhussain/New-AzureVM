<#
.SYNOPSIS
    Creates a VM in Azure based on parameters provided on the commandline.

.DESCRIPTION
    This script creates a Virtual Machine in Azure and uses to account that was added to the
    system where the script is executed prior to running the script. You can use Add-AzureAccount
    for this purpose.
    
    The following extension are activated while creating the VM:
       Azure Desired State Configuration (Azure DSC)
       Windows Azure Diagnostics (WAD)
       Microsoft Monitoring Agent for OMS (MMA)

        
.PARAMETER VMName
    Required parameter for the name of the VM to create. The parameter should pass the following
    validation check ^[a-zA-Z0-9]{3,15}$
    The minimum length is 3 and the maximum is 15. The validation check also only accepts alphanuùeric
    characters.

.PARAMETER VMSize
    Optional parameter that indicates the size of the VM.
    Possible values are:
       ExtraSmall
       Small (Default)
       Medium
       Large
       ExtraLarge

.PARAMETER VMLocation
    Optional parameter that indicates the location of the VM.
    Possible values are:
       West Europe (Default)
       North Europe

.PARAMETER VMOS
    Optional parameter that indicates the OS family name for the VM.
    Possible values are:
       Windows Server 2012 R2 Datacenter (Default)
       Windows Server 2008 R2 SP1

.PARAMETER StorageAccount
    Optional parameter that indicates the storageaccount to use.
    Possible values are:
       portalvhdslys1ks95rj852 (Default)

.PARAMETER ServiceName
    Optional parameter that indicates the servicename to use. This parameter defaults to VMName.
	You can also set the parameter to 'Set to computername' which is the same as the default option.

.PARAMETER SubscriptionName
    Optional parameter that indicates the subscriptionname to use.
    Possible values are:
       Pay-as-You-Go (Default)

.PARAMETER DSCcontainer
    Optional parameter that indicates the storage container in which the DSC configuration will be stored.
    Possible values are:
       dscarchives (Default)

.PARAMETER DSCconfig
    Optional parameter that holds the full path to the DSC configuration file that will be applied after deployment.
    Remark that the confguration name is not configurable via parameters and should always be named InitConfig.
    The parameter contains a validation check that will test if the file is accessible.

.PARAMETER WADconfig
    Optional parameter that holds the full path to the WAD configuration file that will be applied after deployment.
    The parameter contains a validation check that will test if the file is accessible.

.PARAMETER DiskSizeGB
    Optional parameter that holds the size in GB of an eventual extra data disk. Leaving this value to the deault of 0
	omits creating an extra disk.
    The parameter contains a min-max validation of 0-100.

.PARAMETER DiskLabel
    Optional parameter to provide a label for the extra datadisk. The default value is DataDisk.

.PARAMETER VMIP
    Optional parameter to provide a static IP Address for the machine.
	At the moment there's no checks performed to see if the IP is within the range provided in VNetName and SubnetName.
	When omitted or value provided is 10.10.2.0 then na static IP Address is configured.
	The parameter is checked for validity and must start with 10.10.2.

.PARAMETER SubetName
    Optional parameter to provide the name for the subnet in which the machine will be placed.
	At the moment there's no checks performed to see if the subnet is valid for the given VNetName.

.PARAMETER VNetName
    Optional parameter to provide the name for the VNet in which the machine will be placed.
 

.INPUTS
    None, except for the parameters.

.OUTPUTS
    Virtual Machine created in Azure.

.NOTES
    Version:        0.5
    Author:         Rudy MICHIELS
    Creation Date:  07/07/2015
    Purpose/Change: Now using the Getronics Pay-As-You-Go subscription.
  
.EXAMPLE
    new-AzureVM -VMName MYAZUREVM01
    
    Creates the MYAZUREVM01 virtual machine in Azure using all the default settings.

.EXAMPLE
    new-AzureVM -VMName MYAZUREVM01 -VMSize Medium

    Creates the MYAZUREVM01 virtual machine but uses the Medium size and not the default Small size.

.EXAMPLE
    new-AzureVM -VMName MYAZUREVM01 -VMSize Medium -DiskSizeGB 50 -DiskLabel "Data Backup Repository"

    Creates the MYAZUREVM01 virtual machine with Medium size and also an extra disk of 50GB with label <Data Backup Repository>.

#>

### -------------------- PARAMETERS --------------------
param
(
    [Parameter(Mandatory=$true,HelpMessage="Enter a valid computername. Between 3 and 15 long. Only characters and digits!")]
    [ValidatePattern("^[a-zA-Z0-9]{3,15}$")]
    [String]$VMName,

    [Parameter(Mandatory=$false,HelpMessage="Indicates the size of the VM in Azure <ExtraSmall, Small, Medium, Large, ExtraLarge>")]
    [ValidateSet("ExtramSmall","Small","Medium","Large","ExtraLarge")]
    [String]$VMSize = "Small",

    [Parameter(Mandatory=$false,HelpMessage="Where to create the VM <West Europe, North Europe>")]
    [ValidateSet("West Europe","North Europe")]
    [String]$VMLocation = "West Europe",

    [Parameter(Mandatory=$false,HelpMessage="Provide the short name of the OS image.")]
    [ValidateSet("Windows Server 2012 R2 Datacenter","Windows Server 2008 R2 SP1")]
    [String]$VMOS = "Windows Server 2012 R2 Datacenter",

    [Parameter(Mandatory=$false,HelpMessage="Provide the StorageAccount name <portalvhdslys1ks95rj852>")]
    [ValidateSet("portalvhdslys1ks95rj852")]
    [String]$StorageAccount = "portalvhdslys1ks95rj852",

    [Parameter(Mandatory=$false,HelpMessage="Provide the ServiceName name. Defauls to machinename.")]
    [ValidateSet("demogtn","mydur01","Set to computername")]
	[String]$CloudServiceName = "Set to computername",

    [Parameter(Mandatory=$false,HelpMessage="Provide the Azure subscription name to work in.")]
    [ValidateSet("Pay-As-You-Go")]
    [String]$SubscriptionName = "Pay-As-You-Go",

    [Parameter(Mandatory=$false,HelpMessage="Provide the Azure storage container to store the DSC file in.")]
    [ValidateSet("dscarchives")]
    [String]$DSCcontainer = "dscarchives",

    [Parameter(Mandatory=$false,HelpMessage="Provide the full path to the local DSC configuration file.")]
    [ValidateScript({Test-Path $_})]
    [String]$DSCconfig = "C:\Getronics\New-AzureVM\InitialConfig.ps1",

    [Parameter(Mandatory=$false,HelpMessage="Provide the full path to the Windows Azure Diagnostics configuration file.")]
    [ValidateScript({Test-Path $_})]
    [String]$WADconfig = "C:\Getronics\New-AzureVM\wadcfg.xml",

    [Parameter(Mandatory=$false,HelpMessage="Provide the size in GB for the extra data disk.")]
    [ValidateRange(0,100)]
    [Int]$DiskSizeGB = 0,
	
    [Parameter(Mandatory=$false,HelpMessage="Provide a name for the extra data disk.")]
    [String]$DiskLabel = "DataDisk",

    [Parameter(Mandatory=$false,HelpMessage="Provide a static IP address for the machine or enter 10.10.2.0 for DHCP.")]
    [ValidatePattern("\b(10)\.(10)\.(2)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
    [String]$VMIP = "10.10.2.xxx",
	
    [Parameter(Mandatory=$false,HelpMessage="Provide the name for the subnet (default is AllSystems).")]
    [String]$SubnetName = "AllSystems",
	
    [Parameter(Mandatory=$false,HelpMessage="Provide the name for the virtual network (default is dsctesters).")]
    [String]$VNetName = "demogtn",
	
    [Parameter(Mandatory=$false,HelpMessage="Also output logging to screen? (logfile always selected)")]
    [Boolean]$FileAndScreen = $True
)


### -------------------- FUNCTIONS --------------------
Function logThis
{
    PARAM(
         [string]$path,
         [string]$name,
         [string]$message,
         [int]$severity,
         [string]$component,
         [boolean]$screen,
		 [string]$textcolor = "Yellow"
         )
         
         $TimeZoneBias = Get-WmiObject -Query "Select Bias from Win32_TimeZone"
         $DateT= Get-Date -Format "HH:mm:ss.fff"
         $DateD= Get-Date -Format "MM-dd-yyyy"
         $type=1
         
         $logFile = $path + "\" + $name + ".log"

         "<![LOG[$Message]LOG]!><time=$([char]34)$dateT+$($TimeZoneBias.bias)$([char]34) date=$([char]34)$dateD$([char]34) component=$([char]34)$component$([char]34) context=$([char]34)$([char]34) type=$([char]34)$severity$([char]34) thread=$([char]34)$([char]34) file=$([char]34)$([char]34)>"| Out-File -FilePath $logFile -Append -NoClobber -Encoding default

         If ($screen) {
            Write-Host $Message -ForegroundColor $textcolor
        }
}

### -------------------- MODULES --------------------
ipmo Azure

### -------------------- VARIABLES --------------------
$StorageAccountKey = "V1X9lM1WHZiI1JwbhdUb+BnfC7Vbf0w2UUUitc7c05eD0n4QBAT+5rAo3/h+oK3jhsykj5pi5FUrSbjgKwBG9Q=="
$OMSworkspaceId = "c2193f01-7f23-4fd0-ac7f-345d0256a5e5"
$OMSworkspaceKey = "Ovvqm4imjUSum32FZOkBZCiUA8H7FyvU1UuikEjodQB6etyDbaOSr4Eljb+7R++SzfeXfY79BuNRzvlIfR4pVw=="
$AdminAccount = "admin_account"
$AdminAccountPassword = "Password01"
$PublishSettingsFile = "C:\Getronics\New-AzureVM\Pay-As-You-Go-7-7-2015-credentials.publishsettings"
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptPath = split-path -parent $MyInvocation.MyCommand.Path
If ($CloudServiceName -eq "Set to computername") {$ServiceName = $VMName}
Else {$ServiceName = $CloudServiceName}

### -------------------- START LOGGING --------------------
logThis -Screen $FileAndScreen -message "--- STARTED ---" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   VMName: $VMName" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   VMSize: $VMSize" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   VMLocation: $VMLocation" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   VMOS: $VMOS" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   StorageAccount: $StorageAccount" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   ServiceName: $ServiceName" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   SubscriptionName: $SubscriptionName" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   DSCcontainer: $DSCcontainer" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   DSCconfig: $DSCconfig" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "   WADconfig: $WADconfig" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName


### -------------------- BODY --------------------
# Set active Azure subscription.
Import-AzurePublishSettingsFile -PublishSettingsFile "$PublishSettingsFile"
Set-AzureSubscription -SubscriptionName "$SubscriptionName" -CurrentStorageAccountName "$StorageAccount"
Select-AzureSubscription -SubscriptionName "$SubscriptionName"
logThis -Screen $FileAndScreen -message "   Azure subscruption set to <$SubscriptionName> ..." -severity 1 -component "Azure Subscription" -path $ScriptPath -name $ScriptName


# Publish DSC configuration file to Azure storage container.
$StorageContext = New-AzureStorageContext -StorageAccountName "$StorageAccount" -StorageAccountKey "$StorageAccountKey"
Publish-AzureVMDscConfiguration -ConfigurationPath "$DSCconfig" -ContainerName "$DSCcontainer" -StorageContext $StorageContext -Force
logThis -Screen $FileAndScreen -message "     ...<$DSCconfig> published to <$DSCcontainer>..." -severity 1 -component "DSC Configuration" -path $ScriptPath -name $ScriptName


# Get the latest version of the chosen OS image
$AvailableImages = Get-AzureVMImage `
    | where {$_.ImageFamily -like "$VMOS"} `
    | where {$_.Location.Split(";") -contains "$VMLocation"} `
    | Sort-Object -Descending -Property PublishedDate
$LatestImage = $AvailableImages[0].ImageName
logThis -Screen $FileAndScreen -message "     ...Azure VM ImageName has been set to <$LatestImage> ..." -severity 1 -component "VM Image Name" -path $ScriptPath -name $ScriptName

logThis -Screen $FileAndScreen -message "     ...Creating the VM configuration..." -severity 1 -component "VM Configuration" -path $ScriptPath -name $ScriptName
# Start building the VM configuration
$vm = New-AzureVMConfig -Name "$VMName" -InstanceSize "$VMSize" -ImageName "$LatestImage"
$vm = Add-AzureProvisioningConfig -VM $vm -Windows -AdminUsername "$AdminAccount" -Password "$AdminAccountPassword"
logThis -Screen $FileAndScreen -message "     ...AdminAccount and AdminAccountPassword have been set in the VM configuration..." -severity 1 -component "Azure Subscription" -path $ScriptPath -name $ScriptName

# Add the DSC extension
$vm = Set-AzureVMDSCExtension -VM $vm -ConfigurationArchive ((Split-Path $DSCconfig -Leaf) + ".zip") -ConfigurationName "InitConfig" -StorageContext $StorageContext -ContainerName $DSCcontainer -Force
logThis -Screen $FileAndScreen -message "     ...DSC extension has been added to the VM configuration and DSC configuration file set..." -severity 1 -component "DSC Configuration" -path $ScriptPath -name $ScriptName

# Add the Microsoft Montoring Agent for OMS
$vm = Set-AzureVMExtension -VM $vm -Publisher 'Microsoft.EnterpriseCloud.Monitoring' -ExtensionName 'MicrosoftMonitoringAgent' -Version '1.*' -PublicConfiguration "{'workspaceId':  '$OMSworkspaceId'}" -PrivateConfiguration "{'workspaceKey': '$OMSworkspaceKey'}"  
logThis -Screen $FileAndScreen -message "     ...Microsoft Monitoring Agent extension has been added to the VM configuration... " -severity 1 -component "MMA Configuration" -path $ScriptPath -name $ScriptName

# Add the Windows Azure Diagnostics Extension
$vm = Set-AzureVMDiagnosticsExtension -VM $vm -DiagnosticsConfigurationPath "$WADconfig" -StorageContext $StorageContext -Version '1.*'
logThis -Screen $FileAndScreen -message "     ...Windows Azure Diagnostics extension has been added to the VM configuration..." -severity 1 -component "WAD Configuration" -path $ScriptPath -name $ScriptName

# Add Data Disk
If ($DiskSizeInGB -gt 0) {
	$vm = Add-AzureDataDisk -VM $vm -CreateNew -DiskSizeInGB $DiskSizeGB -LUN 0 -DiskName "ExtraDisk1" -DiskLabel "$DiskLabel"
	logThis -Screen $FileAndScreen -message "     ...Created extra data disk of $DiskSizeGB GB with label <$DiskLabel>..." -severity 1 -component "Disk Configuration" -path $ScriptPath -name $ScriptName
}

# Set Network Configuration
$vm = Set-AzureSubnet -VM $vm -SubnetNames "$SubnetName"
If ($VMIP -ne "10.10.2.xxx") {
	$vm = Set-AzureStaticVNetIP -VM $vm -IPAddress "$VMIP"
	logThis -Screen $FileAndScreen -message "     ...Network configuration, Subnet=$SubnetName - Static-IP=$VMIP " -severity 1 -component "Network Configuration" -path $ScriptPath -name $ScriptName
}
	
# Create the VM in Azure
logThis -Screen $FileAndScreen -message "     ...VM is about to be created in Azure..." -severity 1 -component "VM Creation" -path $ScriptPath -name $ScriptName
New-AzureVM -VM $vm -Location "$VMLocation" -ServiceName "$ServiceName" -VNetName "$VNetName"


logThis -Screen $FileAndScreen -message "     ...VM is created, busy provisioning." -severity 1 -component "Azure Subscription" -path $ScriptPath -name $ScriptName
logThis -Screen $FileAndScreen -message "--- ENDED ---" -severity 1 -component "Azure Subscription" -path $ScriptPath -name $ScriptName

