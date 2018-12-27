function Get-cAZPublicRange
{
    [CmdletBinding()]
    param(
        [parameter(mandatory)]
        [string]$regionName,

        [parameter(mandatory=$false)]
        [string]$fileUrl="https://download.microsoft.com/download/0/1/8/018E208D-54F8-44CD-AA26-CD7BC9524A8C/PublicIPs_20181224.xml"
    )
    
    $ErrorActionPreference = "stop"
    $VerbosePreference = "continue"

    $output = "$env:TEMP\azIPs.xml"
    Invoke-WebRequest -Uri $fileUrl -OutFile $output
    $content = [xml](Get-Content -Path $output)

    $regions = $content.AzurePublicIpAddresses.ChildNodes.name
    write-verbose ("valid regions: " + ($regions -join ','))
    $ipRanges = $content.AzurePublicIpAddresses.ChildNodes
    If ($regions -match $regionName)
    {
        $regionSubnets = (($ipranges | ? {$_.Name -eq $regionName}).IPRange).Subnet
        return $regionSubnets
    }
    Else
    {
        throw "Region with name: $regionName is not a valid Azure region"
    }
}
