param name string
param location string = resourceGroup().location
param tags object = {}
param sku string
param managedIdentityName string
param principalId string

var workspaceTitle = 'Default workspace'
var workspaceDescription = 'Default workspace'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource apic 'Microsoft.ApiCenter/services@2024-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}

resource apicWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  name: 'default'
  parent: apic
  properties: {
    title: workspaceTitle
    description: workspaceDescription
  }
}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'apic-currentuser-roleAssignment'
  params: {
    principalId: principalId
    roleName: 'Azure API Center Compliance Manager'
    targetResourceId: apic.id
    deploymentName: 'apic-currentuser-roleAssignment-ComplianceManager'
    principalType: 'User'
  }
}

output apicServiceName string = apic.name
output apicWorkspaceName string = apicWorkspace.name
output apicPortalUrl string = 'https://${apic.name}.portal.${location}.azure-apicenter.ms'
