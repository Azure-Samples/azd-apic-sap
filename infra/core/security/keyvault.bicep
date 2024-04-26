metadata description = 'Creates an Azure Key Vault.'
param name string
param location string = resourceGroup().location
param tags object = {}

param principalId string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enableRbacAuthorization: true
    enableSoftDelete: false
  }
}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'kv-currentuser-roleAssignment'
  params: {
    principalId: principalId
    roleName: 'Key Vault Secrets Officer'
    targetResourceId: keyVault.id
    deploymentName: 'kv-currentuser-roleAssignment-SecretOfficer'
    principalType: 'User'
  }
}

output keyVaultEndpoint string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
