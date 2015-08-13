<#
.SYNOPSIS
    Creates a VM in Azure based input in the GUI.

.DESCRIPTION
    This script creates a Virtual Machine in Azure. Before executing the script you need to add an Azure Account
	to your session manually (Add-AzureAccount). When the scrit is run it shows you a GUI with all required and optional
	input boxes. 
	
	The only required parameter is the VMName. All other inputboxes can be kept at their default values. The VMName
	inputbox also accepts a special keyword. When dbg is entered the script detects this and quits without any action.
	
	After enterring something in the required VMName inputbox you can press enter and the script will threat this as
	a OK-button click and exit the form.
	
	The IP inputbox has a default value of 10.10.2.xxx which tells the script not to add a fixed IP address and 
	select one from the pool.
	
	All actions are logged in a SCCM formatted log file located in the same folder as the script.
    
    The following extension are activated while creating the VM:
       Azure Desired State Configuration (Azure DSC)
       Windows Azure Diagnostics (WAD)
       Microsoft Monitoring Agent for OMS (MMA)

.NOTES
    Version:        0.1
    Author:         Rudy MICHIELS
    Creation Date:  29/06/2015
    Purpose/Change: -
 #>

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

### -------------------- START LOGGING --------------------
[Boolean]$FileAndScreen = $False
$ScriptName = "new-AzureVMGUI"
$ScriptPath = "C:\Getronics\New-AzureVM"
logThis -Screen $FileAndScreen -message "--- STARTED ---" -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName


### -------------------- FORM INPUT --------------------
# Variables
$ProjectName = "New-AzureVM"

# Read the XAML from Visual Studio
logThis -Screen $FileAndScreen -message "Reading input form XAML file..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$inputXML = Get-Content "$ScriptPath\$ProjectName\MainWindow.xaml"

#Remove some unwanted syntax
logThis -Screen $FileAndScreen -message "Removing unwanted XML from input form..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$s1 = 'x:Class="WpfApplication2.MainWindow"'
$s2 = 'mc:Ignorable="d"'
$s3 = 'x:Name='
$filteredXML = $inputXML -replace $s1,"" -replace $s2,"" -replace $s3,"Name="
[xml]$inputXML = $filteredXML

# Make a form out of it
logThis -Screen $FileAndScreen -message "Preparing input form..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms
$Global:Form = [Windows.Markup.XamlReader]::Load((new-object System.Xml.XmlNodeReader $inputXML))

# Create variables for all names
logThis -Screen $FileAndScreen -message "Generating variables for input form boxes..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$inputXML.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -Scope Global}

# Add a Click action to the OK button
logThis -Screen $FileAndScreen -message "Adding click action to OK button..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$WPFbtnOK.Add_Click({$Form.Close()})

# Add Enter-Keydown to txtVMName inputbox
logThis -Screen $FileAndScreen -message "Adding return key action to VMName inputbox..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$WPFtxtVMName.Add_KeyDown({
	If ($_.Key -eq 'Return') {
		logThis -Screen $FileAndScreen -message "Return pressed in VMName inputbox..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
		$Form.Close()
	}
})

# Add a Click action to the Browse DSC button
logThis -Screen $FileAndScreen -message "Adding click action to DSC Browse button..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$WPFbtnDSC.Add_Click({
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $ScriptPath
	$OpenFileDialog.filter = "PS1 files (*.ps1)| *.ps1"
	$OpenFileDialog.ShowDialog() | Out-Null
	$WPFtxtDSC.Text = $OpenFileDialog.filename
})

# Add a Click action to the Browse WAD button
logThis -Screen $FileAndScreen -message "Adding click action to WAD Browse button..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$WPFbtnWAD.Add_Click({
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $ScriptPath
	$OpenFileDialog.filter = "XML files (*.xml)| *.xml"
	$OpenFileDialog.ShowDialog() | Out-Null
	$WPFtxtWAD.Text = $OpenFileDialog.filename
})

# Show the form
logThis -Screen $FileAndScreen -message "Showing the input form..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName
$WPFtxtVMName.Focus() | Out-Null
$Form.ShowDialog() | Out-Null
logThis -Screen $FileAndScreen -message "Exit from input form detected..." -severity 1 -component "InputForm" -path $ScriptPath -name $ScriptName


### -------------------- VAR FROM INPUT FORM --------------------
[String]$VMName = $WPFtxtVMName.Text
[String]$VMSize = $WPFcmbSize.Text
[String]$VMLocation = $WPFcmbLocation.Text
[String]$VMOS = $WPFcmbOS.Text
[String]$StorageAccount = $WPFcmbStorageAccount.Text
If ($ServiceName = "Set to computername") {$ServiceName = $VMName}
Else {[String]$ServiceName = $WPFcmbService.Text}
[String]$SubscriptionName = $WPFcmbSubscription.Text
[String]$DSCcontainer = "dscarchives"
[String]$DSCconfig = $WPFtxtDSC.Text
[String]$WADconfig = $WPFtxtWAD.Text
[Int]$DiskSizeGB = $WPFtxtDiskGB.Text
[String]$DiskLabel = $WPFtxtDiskLabel.Text
[String]$VMIP = $WPFtxtIP.Text
[String]$SubnetName = $WPFcmbSubnet.Text
[String]$VNetName = $WPFcmbVNet.Text

### -------------------- VMName debug keyword? --------------------
If ($VMName -eq "dbg") {
	logThis -Screen $FileAndScreen -message "Debugging keyword detected in VMName, exiting script." -severity 1 -component "newAzureVM" -path $ScriptPath -name $ScriptName
	logThis -Screen $FileAndScreen -message "--- ENDED ---" -severity 1 -component "Azure Subscription" -path $ScriptPath -name $ScriptName
	Exit
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

### -------------------- LOG VARIABLES --------------------
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

