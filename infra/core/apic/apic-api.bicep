param name string
param title string
param description string
param summary string
@allowed(['REST', 'GraphQL', 'gRPC', 'SOAP', 'Webhook', 'WebSocket'])
param kind string
param contactEmail string
param contactName string
param docsTitle string
param docsUrl string
param docsDescription string
param licenseName string
param licenseUrl string
param versionName string
param versionTitle string
@allowed(['Design', 'Development', 'Testing', 'Preview', 'Production', 'Deprecated', 'Retired'])
param versionLifecycle string
param definitionName string
param definitionTitle string
param definitionDescription string
param runtimeUri string
param deploymentName string
param deploymentTitle string
param deploymentDescription string
param apicWorkspaceName string
param apicEnvironmentName string
param apicServiceName string

resource apic 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apicServiceName
}
resource apicWorkspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' existing = {
  name: apicWorkspaceName
  parent: apic
}

resource apicEnvironment 'Microsoft.ApiCenter/services/workspaces/environments@2024-03-01' existing = {
  name: apicEnvironmentName
  parent: apicWorkspace
}

resource apicApi 'Microsoft.ApiCenter/services/workspaces/apis@2024-03-01' = {
  name: name
  parent: apicWorkspace
  properties: {
    contacts: [
      {
        email: contactEmail
        name: contactName
      }
    ]
    description: description
    externalDocumentation: [
      {
        description: docsDescription
        title: docsTitle
        url: docsUrl
      }
    ]
    kind: kind
    license: {
      name: licenseName
      url: licenseUrl
    }
    summary: summary
    title: title
  }
}

resource apicApiVersion 'Microsoft.ApiCenter/services/workspaces/apis/versions@2024-03-01' = {
  name: '${apicApi.name}-${versionName}'
  parent: apicApi
  properties: {
    lifecycleStage: versionLifecycle
    title: versionTitle
  }
}

resource apicApiDefinition 'Microsoft.ApiCenter/services/workspaces/apis/versions/definitions@2024-03-01' = {
  name: '${apicApi.name}-${versionName}-${definitionName}'
  parent: apicApiVersion
  properties: {
    description: definitionDescription
    title: definitionTitle
    // Updating the definition is not supported by the API, done in postProvision
  }
}

resource apicApiDeployment 'Microsoft.ApiCenter/services/workspaces/apis/deployments@2024-03-01' = {
  name: '${apicApi.name}-${deploymentName}'
  parent: apicApi
  properties: {
    definitionId: '/workspaces/${apicWorkspace.name}/apis/${apicApi.name}/versions/${apicApiVersion.name}/definitions/${apicApiDefinition.name}'
    description: deploymentDescription
    environmentId: '/workspaces/${apicWorkspace.name}/environments/${apicEnvironment.name}' 
    server: {
      runtimeUri: [
        runtimeUri
      ]
    }
    title: deploymentTitle
  }
  dependsOn: [
    apicEnvironment
  ]
}

output apicApiName string = apicApi.name
output apicApiVersionName string = apicApiVersion.name
output apicApiDefinitionName string = apicApiDefinition.name
