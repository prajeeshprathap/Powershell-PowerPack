function Get-SonarQube
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[string] $DownloadLink = "https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-5.1.2.zip",

		[Parameter(Mandatory=$false, Position=1)]
		[ValidateScript({Test-Path $_})]
		[string] $DownloadLocation = "C:\Windows\Temp"
	)

	$fileName = $DownloadLink.SubString($DownloadLink.LastIndexOf("/") + 1)

	$target = Join-Path $DownloadLocation $fileName
	
	"Starting download file $DownloadLink" | Write-Verbose
	Invoke-WebRequest -Uri $DownloadLink -OutFile $target
	"Completed download to $target" | Write-Verbose
	$target
}

function Expand-SonarQubePackage
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[ValidateScript({Test-Path $_})]
		[string] $Source = "C:\Windows\Temp\sonarqube-5.1.2.zip",

		[Parameter(Mandatory=$false, Position=1)]
		[string] $Target = "C:\SonarQube"
	)

	if(-not(Test-Path $Target))
	{
		"Creating new folder at location : $Target" | Write-Verbose
		New-Item -ItemType Directory -Path $Target -Force | Out-Null
	}

	Add-Type -AssemblyName "System.IO.Compression.FileSystem" |  Out-Null

	"Extracting the contents of $Source to $Target" | Write-Verbose
	[IO.Compression.ZipFile]::ExtractToDirectory($Source, $Target)
}


function Set-SonarDbProperties
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[ValidateScript({Test-Path $_})]
		[string] $SonarSource = "C:\SonarQube\sonarqube-5.1.2",

		[Parameter(Mandatory=$false, Position=1)]
		[string] $SqlServerName = "localhost",

		[Parameter(Mandatory=$false, Position=2)]
		[string] $DbName = "sonar",
		
		[Parameter(Mandatory=$true, Position=3)]
		[ValidateNotNullOrEmpty()]
		[string] $SqlLogin,

		[Parameter(Mandatory=$true, Position=4)]
		[ValidateNotNullOrEmpty()]
		[string] $SqlPassword
	)


	if(-not(Join-Path $SonarSource "conf\sonar.properties" | Test-Path))
	{
		throw "Failed to find a valid sonarqube configuration file at source location $SonarSource"
	}

	"Updating JDBC url" | Write-Verbose
	$configurationFilePath = Join-Path $SonarSource "conf\sonar.properties"
	(Get-Content $configurationFilePath).Replace("#sonar.jdbc.url=jdbc:jtds:sqlserver://localhost/sonar;SelectMethod=Cursor", "sonar.jdbc.url=jdbc:jtds:sqlserver://$SqlServerName/$DbName;SelectMethod=Cursor") | Set-Content $configurationFilePath

	"Updating JDBC username" | Write-Verbose
	(Get-Content $configurationFilePath).Replace("#sonar.jdbc.username=sonar", "sonar.jdbc.username=$SqlLogin") | Set-Content $configurationFilePath
	
	"Updating JDBC password" | Write-Verbose
	(Get-Content $configurationFilePath).Replace("#sonar.jdbc.password=sonar", "sonar.jdbc.password=$SqlPassword") | Set-Content $configurationFilePath
}

function Install-SonarQubeService
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$false, Position=0)]
		[ValidateScript({Test-Path $_})]
		[string] $SonarSource = "C:\SonarQube\sonarqube-5.1.2"
	)

	if(-not(Join-Path $SonarSource "bin\windows-x86-64\InstallNTService.bat" | Test-Path))
	{
		throw "Failed to find a sonarqube installation file"
	}

	if(( Get-Service |? {$_.Name -eq "SonarQube" }) -eq $null)
	{
		"Installing SonarQube service" | Write-Verbose
		Start-Process -FilePath (Join-Path $SonarSource "bin\windows-x86-64\InstallNTService.bat") -Wait -NoNewWindow
	}
}