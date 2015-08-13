Configuration InitConfig
{
        Import-DscResource -ModuleName xPSDesiredStateConfiguration, xChrome

		WindowsFeature Telnet-Server
		{
			Ensure = "Present"
			Name = "Telnet-Server"
		}
		WindowsFeature Telnet-Client
		{
			Ensure = "Present"
			Name = "Telnet-Client"
		}
		WindowsFeature IIS
		{
			Ensure = "Present"
			Name = "Web-Server"
		}
		WindowsFeature ASP
		{
			Ensure = "Present"
			Name = "Web-Asp-Net45"
		}
		Registry GTSRegKey
		{
			Ensure = "Present"
			Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Getronics"
			ValueName = "BillingIdentification"
			ValueData = "PLAN2"
			ValueType = "String"			
		}
        File GTSFolder {
            Type = 'Directory'
            DestinationPath = 'C:\Getronics'
            Ensure = "Present"
        }
        File GTSFile {
            Type = 'File'
            DestinationPath = 'C:\Getronics\Readme.txt'
            Ensure = "Present"
            Contents = 'Please use this folder for all Getronics related documents and downloads.'
            DependsOn = "[File]GTSFolder"
        }
        MSFT_xChrome Chrome
        {
            Language = "en"
            LocalPath = "C:\Windows\Temp\GoogleChromeStandaloneEnterprise.msi"
        }
}
