metadata description = 'Creates an Azure API Management instance.'
param name string
param location string = resourceGroup().location
param tags object = {}

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'n/a'

@description('The pricing tier of this API Management service')
param sku string

@description('The instance size of this API Management service.')
param skuCount int

@description('Azure Application Insights Name')
param applicationInsightsName string

param managedIdentityName string
param apicManagedIdentityName string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

//setting explicit public IP for APIM will force stV2 instance of APIM
resource apimPublicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' existing = if(sku != 'StandardV2'){
  name: '${name}-pip'
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource apicManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apicManagedIdentityName
}

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicIpAddressId: sku != 'StandardV2' ? apimPublicIp.id : null
    developerPortalStatus: 'Enabled'
    // Custom properties are not supported for Consumption SKU
    customProperties: sku == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apiConsumerSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
  parent: apimService
  name: 'consumer-subscription'
  properties: {
    scope: '/apis'
    displayName: 'Consumer'
    state: 'active'
    allowTracing: true
  }
}

module apicManagedIdentityRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'apim-apic-roleAssignment'
  params: {
    principalId: apicManagedIdentity.properties.principalId
    roleName: 'API Management Service Reader'
    targetResourceId: apimService.id
    deploymentName: 'apim-apic-roleAssignment-ServiceReader'
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = if (!empty(applicationInsightsName)) {
  name: 'app-insights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

output apimServiceName string = apimService.name
output apimLoggerName string = apimLogger.name
output apimDeveloperPortalUrl string = apimService.properties.developerPortalUrl
output apimManagementPortalUrl string = apimService.properties.managementApiUrl
output apimGatewayUrl string = apimService.properties.gatewayUrl
output apimResourceId string = apimService.id
