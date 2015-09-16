function RetrievePackages
{
	param($path, $registry)
	
	$packages = @()
	$key = $registry.OpenSubKey($path) 
	$subKeys = $key.GetSubKeyNames() |% {
		$subKeyPath = $path + "\\" + $_ 
		$packageKey = $registry.OpenSubKey($subKeyPath) 
		$package = New-Object PSObject 
		$package | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $($packageKey.GetValue("DisplayName"))
		$package | Add-Member -MemberType NoteProperty -Name "DisplayVersion" -Value $($packageKey.GetValue("DisplayVersion"))
		$package | Add-Member -MemberType NoteProperty -Name "UninstallString" -Value $($packageKey.GetValue("UninstallString")) 
		$package | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $($packageKey.GetValue("Publisher")) 		
		$packages += $package	
	}
	return $packages
}

function Get-InstalledSoftwares
{
	$installedSoftwares = @{}
	$path = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 
    $registry32 = [microsoft.win32.registrykey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
    $registry64 = [microsoft.win32.registrykey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
	$packages = RetrievePackages $path $registry32
	$packages += RetrievePackages $path $registry64

	$packages.Where({$_.DisplayName}) |% { 
		if(-not($installedSoftwares.ContainsKey($_.DisplayName)))
		{
			$installedSoftwares.Add($_.DisplayName, $_) 
		}
	}
    $installedSoftwares.Values
}

function Initialize-Assembly
{
	param
	(
		[Parameter(Mandatory=$true, Position=0, ParameterSetName="Single")]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory=$true, Position=0, ParameterSetName="Array")]
		[ValidateNotNullOrEmpty()]
		[string[]] $Names

	)
	
	switch($PSCmdlet.ParameterSetName)
	{
		"Single"
		{
			[void][System.Reflection.Assembly]::LoadWithPartialName($Name)
			break
		}
		"Array"
		{
			$Names |% { [void][System.Reflection.Assembly]::LoadWithPartialName($_) }
			break
		}
	}
}

function Test-AssemblyLoaded
{
	param
	(
		[Parameter(Mandatory=$true, Position=0, ParameterSetName="Single")]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory=$true, Position=0, ParameterSetName="Array")]
		[ValidateNotNullOrEmpty()]
		[string[]] $Names

	)

	switch($PSCmdlet.ParameterSetName)
	{
		"Single"
		{
			(Get-AssemblyLoaded |? {$_ -match $Name}) -ne $null
			break
		}
		"Array"
		{
			$result = $true
			$assemblies = Get-AssemblyLoaded
			$Names |% {
				$assembly = $_
				if(($assemblies |? {$_ -match $assembly}) -eq $null)
				{
					$result = $false
				}
			}

			$result
			break
		}
	}
}

function Get-AssemblyLoaded
{
	[System.AppDomain]::CurrentDomain.GetAssemblies()
}


function New-FirewallRule
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=0)]
		[ValidateNotNullOrEmpty()]
		[string] $Name,

		[Parameter(Mandatory=$true, Position=1)]
		[ValidateNotNullOrEmpty()]
		[string] $TCPPorts,

		[Parameter(Mandatory=$false, Position=2)]
		[string] $ApplicationName,
		
		[Parameter(Mandatory=$false, Position=3)]
		[string] $ServiceName
	)

	$firewall = New-Object -ComObject hnetcfg.fwpolicy2 

	if( ($firewall.Rules | select -expand localports |? {$_ -eq $TCPPorts }) -eq $null)
	{
		"Adding firewall rule to open ports $TCPPorts" | Write-Verbose
		$rule = New-Object -ComObject HNetCfg.FWRule
        
		$rule.Name = $name
		if (-not ([string]::IsNullOrEmpty($ApplicationName)))
		{ 
			$rule.ApplicationName = $ApplicationName 
		}
		if (-not ([string]::IsNullOrEmpty($ServiceName)))
		{ 
			$rule.serviceName = $ServiceName 
		}
		$rule.Protocol = 6 #NET_FW_IP_PROTOCOL_TCP
		$rule.LocalPorts = $TCPPorts
		$rule.Enabled = $true
		$rule.Grouping = "@firewallapi.dll,-23255"
		$rule.Profiles = 7 # all
		$rule.Action = 1 # NET_FW_ACTION_ALLOW
		$rule.EdgeTraversal = $false
    
		$firewall.Rules.Add($rule)
	}
    else
	{
		"The firewall rule for $TCPPorts already exists"  | Write-Verbose
	}
}

function Set-ServiceLogonProperties
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $Name = "SonarQube",

		[Parameter(Mandatory=$false, Position=1)]
		[string] $Username = "$env:USERDOMAIN\$env:USERNAME"
	)

	$credential = Get-Credential -UserName $Username -Message "Provide password"
	$password = $credential.GetNetworkCredential().Password

	$filter = 'Name=' + "'" + $Name + "'" + ''
	$service = Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter
	$service.Change($null,$null,$null,$null,$null,$null,$Username,$password)
	$service.StopService()

	while ($service.Started)
	{
		sleep 2
		$service = Get-WMIObject -namespace "root\cimv2" -class Win32_Service -Filter $filter
	}
	$service.StartService()
}

Export-ModuleMember *Assembly*, Get*, New*, Set*
