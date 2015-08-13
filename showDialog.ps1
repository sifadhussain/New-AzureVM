#Variables
$ProjectName = "New-AzureVM"
$ScriptPath = "C:\Getronics"

#Read the XAML from Visual Studio
$inputXML = Get-Content "$ScriptPath\$ProjectName\MainWindow.xaml"

#Remove some unwanted syntax
$s1 = 'x:Class="WpfApplication2.MainWindow"'
$s2 = 'mc:Ignorable="d"'
$s3 = 'x:Name='
$filteredXML = $inputXML -replace $s1,"" -replace $s2,"" -replace $s3,"Name="
[xml]$inputXML = $filteredXML

#Make a form out of it
Add-Type -AssemblyName PresentationCore,PresentationFramework,WindowsBase,system.windows.forms
$Global:Form = [Windows.Markup.XamlReader]::Load((new-object System.Xml.XmlNodeReader $inputXML))

#Create variables for all names
$inputXML.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -Scope Global}


#Add a Click action to the OK button
$WPFbtnOK.Add_Click({$Form.Close()})

#Add a Click action to the Browse DSC button
$WPFbtnDSC.Add_Click({
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $ScriptPath
	$OpenFileDialog.filter = "XML files (*.xml)| *.xml"
	$OpenFileDialog.ShowDialog() | Out-Null
	$WPFtxtDSC.Text = $OpenFileDialog.filename
})

#Add a Click action to the Browse DSC button
$WPFbtnWAD.Add_Click({
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
	$OpenFileDialog.initialDirectory = $ScriptPath
	$OpenFileDialog.filter = "PS1 files (*.ps1)| *.ps1"
	$OpenFileDialog.ShowDialog() | Out-Null
	$WPFtxtWAD.Text = $OpenFileDialog.filename
})

#Add a Click action to the OK button
$WPFbtnOK.Add_Click({$Form.Close()})

#Show the form
$Form.ShowDialog() | Out-Null

#Test an inputbox value
$WPFtxtVMName.Text
$WPFtxtWAD.Text



