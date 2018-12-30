function Export-cAZPolicyDefinitions {
    [cmdletBinding()]
    param(
        [parameter(mandatory)]
        [string]$outputFolder
    )

    function trim-jsontabs {
        param(
        [parameter(mandatory)]
        [string]$inputData,

        [parameter(mandatory=$false)]
        [int]$depth=3
        )

        $outputData = (($inputData -split '\r\n' | Foreach-Object {
        $line = $_
        if ($_ -match '^ +') {
            $len  = $Matches[0].Length / $depth
            $line = ' ' * $len + $line.TrimStart()
        }
        $line
        }) -join "`r`n")

        return $outputData
    }

    #Get Policy Definitions
    $definitions = Get-AzureRmPolicyDefinition

    #Instantiate Inventory
    $inventoryData = @()
    Foreach ($def in $definitions)
    {
        $json = $def | ConvertTo-Json -Depth 50 | Foreach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
        $jsonshort = trim-jsontabs -inputData $json -depth 3
        #Add to Inventory
        $iObj = [pscustomobject][ordered]@{
            Name = $def.Name
            DisplayName = $def.Properties.displayName
            PolicyType = $def.Properties.policyType
            Category = $def.Properties.metadata.category
            Description = $def.Properties.description
        }
        $inventoryData += $iObj

        #Create output json
        $jsonshort | out-file -FilePath "$outputFolder\$($def.Name).json" -Force
    }

    #Export Inventory
    $inventoryData | Export-Csv -Path "$outputFolder\_inventory.csv" -NoClobber -Delimiter ',' -Encoding UTF8 -Force -NoTypeInformation
}

