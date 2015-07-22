Function Get-NugetPackages
{    
    param
    (
        [String] $Source = "http://prajeeshnuget.azurewebsites.net/nuget",
        [switch] $IncludePreRelease,
        [switch] $AllVersions,

        [ValidateScript({Test-Path $_ -PathType Leaf -Include "nuget.exe"})]
        [String] $NugetLocation = (Join-Path $PSScriptRoot "nuget.exe")
    )

    $command = $NugetLocation + " list "

    if(-not ([String]::IsNullOrEmpty($Source)))
    {
        $command += " -s "  + $Source
    }

    if($IncludePreRelease)
    {
        $command += " -Prerelease"
    }

    if($AllVersions)
    {
        $command += " -AllVersions"
    }

    Invoke-Expression $command
}

Function UnPublish-NugetPackage
{
    param
    (
        [string] $Source = "http://prajeeshnuget.azurewebsites.net",

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNull()]
        [switch] $PackageId,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNull()]
        [switch] $Version,

        [string] $APIKey = "MYKEY",

        [ValidateScript({Test-Path $_ -PathType Leaf -Include "nuget.exe"})]
        [String] $NugetLocation = (Join-Path $PSScriptRoot "nuget.exe")
    )

    $command = $NugetLocation + " delete $($PackageId) $($Version) $($APIKey) -NoPrompt"
    if(-not ([String]::IsNullOrEmpty($Source)))
    {
        $command += " -s "  + $Source
    }

    Invoke-Expression $command
}

Function Publish-NugetPackage
{
    param
    (
        [string] $Source = "http://prajeeshnuget.azurewebsites.net",

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNull()]
        [ValidateScript({Test-Path $_})]
        [switch] $PackagePath,
        
        [string] $APIKey = "MYKEY",

        [ValidateScript({Test-Path $_ -PathType Leaf -Include "nuget.exe"})]
        [String] $NugetLocation = (Join-Path $PSScriptRoot "nuget.exe")
    )

    $command = $NugetLocation + " push $($PackagePath) $($APIKey)"
    if(-not ([String]::IsNullOrEmpty($Source)))
    {
        $command += " -s "  + $Source
    }

    Invoke-Expression $command
}

Function New-NugetPackage
{
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNull()]
        [ValidateScript({Test-Path $_})]
        [switch] $NuspecPath,

        [ValidateScript({Test-Path $_ -PathType Leaf -Include "nuget.exe"})]
        [String] $NugetLocation = (Join-Path $PSScriptRoot "nuget.exe"),

        [string] $OutputDirectory
    )
    $command = $NugetLocation + " pack $($NuspecPath)"

    if(-not ([String]::IsNullOrEmpty($OutputDirectory)))
    {
        $command += " -OutputDirectory "  + $OutputDirectory
    }

    Invoke-Expression $command
}

Export-ModuleMember -Function *-Nuget* 
