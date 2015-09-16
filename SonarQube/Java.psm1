function Install-JavaRuntimeEnvironment
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=0)]
		[ValidateScript({Test-Path $_})]
		[string] $JreInstallerPath
	)

	"Installing java runtime environment" | Write-Verbose

	$arguments = "/s SPONSORS=0 /L $Env:Temp\jre_install.log"

	$proc = Start-Process $JreInstallerPath -ArgumentList $arguments -Wait -NoNewWindow -PassThru
	if($proc.ExitCode -ne 0) 
	{
		throw "Unexpected error installing java runtime environment"
	}
	[Environment]::SetEnvironmentVariable('JAVA_HOME', "C:\Program Files\Java\jre1.8.0_60\bin", "Machine")
}

function Test-JavaInstalled
{
	$javaPackage = Get-InstalledSoftwares |? {$_.DisplayName.Contains('Java 8 Update 60')}
	return $javaPackage -ne $null
}