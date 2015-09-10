$ErrorActionPreference = "Stop"

function Test-CurrentUserAdmin
{
	[CmdletBinding()]
	param()

	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = $identity -as [Security.Principal.WindowsPrincipal]
	if($principal -eq $null)
	{
		throw "Failed to intiailize the windows principal instance from windows identity of the current user"
	}
	if(-not($principal.IsInRole("Administrators")))
	{
		throw "The current user is not added to the Adminstrators group. Start the installation using an Admin account"
	}
	else
	{
		"The current user is an administrator. Installation will start now" | Write-Verbose
	}
}

function Install-Product
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
	    [ValidateScript({[System.IO.File]::Exists($_)})]
	    [string] $ExecutablePath,

	    [Parameter(Mandatory=$false)]
	    [string] $ProductKey
    )

    "Checking whether the current user is an Administrator" | Write-Debug
    Test-CurrentUserAdmin -Verbose

    "Visual studio setup locaiton : $($ExecutablePath)" | Write-Debug

    $adminDeployment = (Join-Path $PSScriptRoot 'AdminDeployment.xml')

    if(-not (Test-Path $adminDeployment))
    {
        throw "Failed to find a valid AdminDeployment.xml file at the script location"
    }

    "Default admin deployment file : $adminDeployment" | Write-Debug

    $args = "/Quiet /NoRestart /AdminFile $adminDeployment /Log $Env:Temp\VisualStudio2015_Install.log"
 
    if($ProductKey)
    {
        $args = $args + " /ProductKey $ProductKey"
    }

    "Installation arguments : $args" | Write-Debug
    "Starting installation" | Write-Verbose

    Start-Process -FilePath $ExecutablePath -ArgumentList $args -Wait -NoNewWindow       

	"Successfully completed the installation" | Write-Verbose
}

function Uninstall-Product
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
	    [ValidateScript({[System.IO.File]::Exists($_)})]
	    [string] $ExecutablePath
    )
	
    "Checking whether the current user is an Administrator" | Write-Debug
    Test-CurrentUserAdmin -Verbose

	$args = "/Quiet /Force /Uninstall /Log $Env:Temp\VisualStudio2015_Uninstall.log"
 
	"Uninstallation arguments : $args" | Write-Debug
    "Starting uninstallation" | Write-Verbose

    Start-Process -FilePath $ExecutablePath -ArgumentList $args -Wait -NoNewWindow       

	"Successfully completed the uninstallation" | Write-Verbose
}

Export-ModuleMember Install*, Uninstall*
