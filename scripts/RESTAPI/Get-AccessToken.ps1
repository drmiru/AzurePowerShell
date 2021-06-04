#Variant with MSAL module
#Get Access Token using cert authN
Import-Module MSAL.PS
Get-MsalToken -ClientId '<app id>' -TenantId '<tenant id>' -ClientCertificate '<$cert obj>'


