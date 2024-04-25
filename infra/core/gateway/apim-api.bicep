param name string
param path string
param displayName string
param SpecUrl string
param apimServiceName string
param apimLoggerName string
param keyVaultEndpoint string
param sapKeyVaultSecretName string
param managedIdentityName string
param sapUri string
param logBytes int = 8192

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: logBytes }
}
var sapApiKeyNamedValue = 'sap-apikey'
var sapApiBackendId = 'sap-backend'

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' existing = {
  name: apimLoggerName
  parent: apimService
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource apimSapApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: name
  parent: apimService
  properties: {
    path: path
    displayName: displayName
    subscriptionRequired: true
    format: 'odata-link'
    value:  SpecUrl
    protocols: [
      'https'
      'http'
    ]
  }
}

resource apimSapBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  name: sapApiBackendId
  parent: apimService
  properties: {
    description: sapApiBackendId
    url: sapUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource apimSapApiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  name: sapApiKeyNamedValue
  parent: apimService
  properties: {
    displayName: sapApiKeyNamedValue
    secret: true
    keyVault:{
      secretIdentifier: '${keyVaultEndpoint}secrets/${sapKeyVaultSecretName}'
      identityClientId: apimService.identity.userAssignedIdentities[managedIdentity.id].clientId
    }
  }
}

resource apiPolicies 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimSapApi
  properties: {
    value: loadTextContent('./policies/api-policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apimSapBackend
    apimSapApiKeyNamedValue
  ]
}

/*
resource diagnosticsPolicy 'Microsoft.ApiManagement/service/apis/diagnostics@2023-03-01-preview' = if (!empty(apimLogger.name)) {
  name: 'sap-app-insights'
  parent: apimSapApi
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}
*/
output SERVICE_API_URI string = '${apimService.properties.gatewayUrl}/${apimSapApi.properties.path}'
