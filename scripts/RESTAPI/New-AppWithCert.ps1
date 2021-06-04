param(
    [Parameter(mandatory=$true)]
    [string]$appName,

    [Parameter(mandatory=$true)]
    [string]$tenantId,

    [Parameter(mandatory=$true)]
    [string]$tenantName,

    [Parameter(mandatory=$false)]
    [string]$keyvaultName,

    [Parameter(mandatory=$false)]
    [bool]$uploadToKeyVault=$false,

    [Parameter(mandatory=$false)]
    [string[]]$graphPermissions=@(
    "Group.Read.All",
    "User.Read.All"
    )
)

$ErrorActionPreference = 'stop'

#Import required modules
Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Az.KeyVault
Import-Module AzureADPreview


#Check if we are oprating in the right context
$azcontext = Get-AzContext
If (-not $azcontext -or ($azcontext.Tenant.Id -ne $tenantId)) {
    connect-azaccount -Tenant $tenantName -UseDeviceAuthentication
    connect-azuread -TenantId $tenantId
}
try {
    $aadContext = Get-AzureADTenantDetail
}
catch {}
If (-not $aadContext -or ($aadContext.objectId -ne $tenantId)) {
    Connect-AzureAD -tenantId $tenantId
}

#Create certificate
$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=$appName" -KeySpec KeyExchange -NotAfter (Get-Date).AddYears(2)
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

#Create AD App with Service Principal
try {
    $sp = New-AzADServicePrincipal -DisplayName $appName -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore
    # Add Graph API Permissions
    #Get graph App
    $graphApp = Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

    #get Role to read group objects
    Foreach ($p in $graphPermissions) {
        $permEntry = $graphApp.AppRoles | where-Object {$_.Value -eq $p}
        write-verbose "Granting permission: $($permEntry.Value)"
        $null = New-AzureADServiceAppRoleAssignment -Id $permEntry.Id -ObjectId $sp.Id -PrincipalId $sp.Id -ResourceId $graphApp.ObjectId 
    }

    #Upload to keyvault
    If ($uploadToKeyVault -eq $true) {
        #export cert
        $certPath = "$ENV:userprofile\$appName.pfx"
        Export-PfxCertificate -Cert $cert -FilePath $certPath -Password ($cert.Thumbprint | ConvertTo-SecureString -AsPlainText -Force)
        
        #upload cert
        Import-AzKeyVaultCertificate -VaultName $keyvaultName -FilePath $certPath -Name $appName -Password ($cert.Thumbprint | ConvertTo-SecureString -AsPlainText -Force) 

        #remove exported file 
        remove-item $certPath -Force
    }

    #return service Principal
    return $sp
}
catch {
    write-warning $_.Exception.Message
    Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.subject -match $appName} | remove-item
}

