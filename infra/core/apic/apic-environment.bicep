param name string
param title string
param description string
@allowed(['Development', 'Testing', 'Staging', 'Production'])
param kind string
@allowed(['Azure API Management', 'Azure Compute service', 'ApiGee API Management', 'AWS API Gateway', 'Kong API Gateway', 'Kubernetes', 'MuleSoft API Management'])
param environmentType string
param developerPortalUri string
param managementPortalUri string
param apicWorkspaceName string
param apicServiceName string

resource apic 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apicServiceName
}

resource apicWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' existing = {
  name: apicWorkspaceName
  parent: apic
}

resource apicEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-03-01' = {
  name: name
  parent: apicWorkspace
  properties: {
    description: description
    kind: kind
    onboarding: {
      developerPortalUri: [
        developerPortalUri
      ]
    }
    server: {
      managementPortalUri: [
        managementPortalUri
      ]
      type: environmentType
    }
    title: title
  }
}

output apicEnvironmentName string = apicEnvironment.name
