param(
    [string]$appName="d-spi-graphdemo",
    [string]$tenantId="ff1a6977-6e45-4657-b188-9e70e57310a8",
    [string]$tenantName="scopewyselabs.com",
    [string[]]$graphPermissions=@(
    "Group.Read.All",
    "User.Read.All"
    )
)


#Create new App with service principal
$sp = .\New-AppWithCert.ps1 -appName $appName -tenantId $tenantId -tenantName $tenantName -graphPermissions $graphPermissions

#retrieve certificate
$cert = (ls Cert:\CurrentUser\my | where {$_.subject -match $appName})

#Get Access Token using cert authN
$accessToken = (Get-MsalToken -ClientId ($sp.ApplicationId).ToString() -TenantId $tenantId -ClientCertificate $cert).AccessToken

#Invoke graph requests
$authHeader = @{
    'Content-Type'='application/json'
    'Authorization'="Bearer $accessToken"
}

#Get users
$uri = "https://graph.microsoft.com/v1.0/users"
$users = (Invoke-RestMethod -Method Get -Uri $uri -Headers $authHeader).value

#Get single user
$uri = "https://graph.microsoft.com/v1.0/users/michael.rueefli@scopewyselabs.com"
$userInfo = (Invoke-RestMethod -Method Get -Uri $uri -Headers $authHeader)

#Update a user
$newJobTitle = "Solutions Architect"

$body = @"
{
    "jobTitle" : "$newJobTitle"
}
"@
$uri = "https://graph.microsoft.com/v1.0/users/michael.rueefli@scopewyselabs.com"
Invoke-RestMethod -Method Patch -Uri $uri -Headers $authHeader -Body $body

#Some fun with the profile picture
#Invoke graph requests
$authHeader = @{
    'Content-Type'='image/jpeg'
    'Authorization'="Bearer $accessToken"
}

$imageData = ([Byte[]] $(Get-Content -Path "C:\Users\MichaelRüefli\Pictures\fox.jpg" -Encoding Byte -ReadCount 0))
$uri = "https://graph.microsoft.com/v1.0/users/michael.rueefli@scopewyselabs.com/photo/`$value"
Invoke-RestMethod -Method PUT -Uri $uri -Headers $authHeader -Body $imageData

