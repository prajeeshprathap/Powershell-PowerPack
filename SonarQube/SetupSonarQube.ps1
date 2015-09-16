[CmdletBinding()]
param
(
	[Parameter(Mandatory=$false)]
	[string] $SqlServer = "localhost"
)

$Error.Clear()
if(Get-Module SonarQube)
{
	Remove-Module SonarQube
}
$Global:CurrentDirectory = Split-Path $Script:MyInvocation.MyCommand.Path
Import-Module "$CurrentDirectory\SonarQube.psd1"
$Global:RunAsVerboseSession = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose')
$Global:RunAsDebugSession = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Debug')

#Validate SQL server prerequisites
if(-not(Test-SqlServerProperties $SqlServer -Verbose:$RunAsVerboseSession))
{
	"Unable to validate SQL Server properties on the server : $SqlServer" | Write-Warning
	"You need to ensure that the database requirements match the SonarQube specifications" | Write-Warning
}

$installFolder = "C:\Software\Tools"
$source = "C:\Temp\SonarQube-5.1.2.zip"

#Download SonarQube server files
if(-not(Test-Path $source))
{
	Get-SonarQube -DownloadLocation (Split-Path -Parent $source) -Verbose:$RunAsVerboseSession
}

#Extract SonarQube files to the installation folder
$sonarQubeFolder = Join-Path $installFolder ([IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $source)))
if(-not(Test-Path $sonarQubeFolder))
{
	Expand-SonarQubePackage -Source $source -Target $installFolder -Verbose:$RunAsVerboseSession
}

#Install JRE
if(-not (Test-JavaInstalled))
{
	Install-JavaRuntimeEnvironment "C:\Software\Tools\jre-8u60-windows-x64.exe" -Verbose:$RunAsVerboseSession
}

#Set SQL authentication mode
Set-AuthenticationMode -AuthenticationMode "Mixed" -Verbose:$RunAsVerboseSession

#Add user for SonarQube
Set-SqlLogin -Username "sonaruser" -Password "SonarPass@12" -Verbose:$RunAsVerboseSession

#Create database for SonarQube
New-SqlDatabase -DbName "sonar" -Verbose:$RunAsVerboseSession

#Set SonarUser with db_owner role in database
Set-DbLogin -DbName "sonar" -Username "sonaruser" -Role "db_owner" -Verbose:$RunAsVerboseSession

#Open Firewall ports
New-FirewallRule -Name "Allow SonarQube port 9000"  -TCPPorts "9000" -Verbose:$RunAsVerboseSession

#Set JDBC URL, Username and Password
Set-SonarDbProperties -SonarSource (Join-Path $installFolder sonarqube-5.1.2) -SqlLogin "sonaruser" -SqlPassword "SonarPass@12" -Verbose:$RunAsVerboseSession

#Install SonarQube Service
Install-SonarQubeService -SonarSource (Join-Path $installFolder sonarqube-5.1.2) -Verbose:$RunAsVerboseSession

#Setup sonarqube service account credentials
Set-ServiceLogonProperties -Verbose:$RunAsVerboseSession