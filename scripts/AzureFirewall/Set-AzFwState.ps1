#Requires -Version 6.2
[CmdletBinding()]
param (
[Parameter(Mandatory)]
[string]$firewallName,

[Parameter(Mandatory)]
[ValidateSet('start','stop')]
[string]$operation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "stop"

#Import required Modules
write-verbose -message "importing required modules"
$VerbosePreference = "SilentlyContinue"
try {
    Import-Module -Name Az.Network -MinimumVersion 1.14.0
}
catch {
    throw "Error Importing PowerShell Module: $($_.Exception.Message)"
}
If ($PSBoundParameters.Keys -match 'verbose') {
    $VerbosePreference = 'Continue'
}

#Get the firewall object
write-verbose -message "get the firewall object: $firewallName"
$fwObject = Get-AzFirewall -Name $firewallName
If (!$fwObject) {
    throw "No Firewall Object Found with name: $firewallName"
}

Switch ($operation.ToLower()) {
    "stop" {
                      
        #Save or update the current State and Metainfo to resource tag
        try {
            write-verbose -message "Parsing Firewall Object Details"
            $virtualNetworkName = ((($fwobject.IpConfigurations | Where-Object {$_.Subnet}).Subnet.Id -split '/subnets')[0] -split('/'))[-1] 
            $resourceGroupName = (($fwobject.IpConfigurations | Where-Object {$_.Subnet}).Subnet.Id -split ('/resourceGroups/') -split('/providers'))[1]
            $publicIpAddressIds = $fwObject.IpConfigurations.PublicIPAddress.Id
            $publicIPs = @()
            Foreach ($pip in $publicIpAddressIds) {
                write-verbose -message "Querying Public IP Object: $pip"
                $fwPublicIpAddress = (Get-AzPublicIpAddress -Name ($pip -split '/')[-1]).IpAddress
                $publicIPs += $fwPublicIpAddress
            }
            $fwEntity = [PSCUSTOMOBJECT]@{
                PublicIPAddresses = $publicIPs
                VirtualNetwork = $virtualNetworkName
                resourceGroupName = $resourceGroupName
            }
            try {
                write-verbose -message "Saving Information to Tag: FirewallInfo"
                Set-AzResource -Tag @{FirewallInfo=($fwEntity | ConvertTo-Json)} -ResourceId $fwObject.Id -Force | out-null
            }
            catch {
                throw "failed to save firewall information to Tags. skipping stop operation"
            }
        }
        catch {
            throw "Error while gathering current IP Configuration: $($_.Exception.Message)"
        }

        #Stop the Firewall Instance and update entry in table
        try {
            $fwObject.Deallocate()
            write-output "Stopping Firewall: $firewallName"
            Set-AzFirewall -AzureFirewall $fwObject | Out-Null
        }
        catch {
            throw "Error deallocating Azure Firewall: $($fwObject.Name). $($_.Exception.Message)"
        }
    }
    "start" {
        #Get the data from table storage
        try {
            write-verbose -message "Reading information from Tag: FirewallInfo"
            $fwIpConfig = $fwObject.tag.FirewallInfo | ConvertFrom-Json
            If (!$fwIpConfig) {
                throw "Error: No IP Configuration found for Azure Firewall: $($fwObject.Name)"
            }
            $virtualNetworkName = $fwIpConfig.VirtualNetwork
            $resourceGroupName = $fwIpConfig.resourceGroupName

        }
        catch {
            throw "Error Getting entry for Azure Firewall: $($fwObject.Name). $($_.Exception.Message)"
        }

        #attach the public IP and start the firewall
        try {
            #get the vnet
            write-verbose -message "Query virtual Network Object: $($fwIpConfig.VirtualNetwork)"
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $fwIpConfig.resourceGroupName -Name $fwIpConfig.VirtualNetwork
            
            #allocate first public IP
            write-verbose -message ('Allocating primary Public IP Address:' + ($fwIpConfig.PublicIPAddresses)[0])
            $primaryPublicIp = Get-AzPublicIpAddress | where-object { $_.IpAddress -eq ($fwIpConfig.PublicIPAddresses)[0]}
            try {
                $fwObject.Allocate($vnet,$primaryPublicIp)
            }
            Catch {
                write-warning $_.Exception.Message
            }
            

            Foreach ($pubIp in $fwIpConfig.PublicIPAddresses) {
                If ($pubIp -notmatch $primaryPublicIp) {
                    try {
                        write-verbose -message "Allocating additional public IP: $pubIp"
                        $publicip = Get-AzPublicIpAddress | where-object {$_.IpAddress -eq $pubIp}
                        $fwObject.AddPublicIpAddress($publicip)
                    }
                    Catch {
                        write-warning $_.Exception.Message
                    }
                }
            }
            
            #Update / Start the firewall instance
            write-output "Starting Firewall: $firewallName"
            Set-AzFirewall -AzureFirewall $fwObject
        }
        catch {
            throw "Error starting Azure Firewall: $($fwObject.Name). $($_.Exception.Message)"
        } 
    }
}
