targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed([
  'australiaeast'
  'centralindia'
  'eastus'
  'uksouth'
  'westeurope'
])
param location string

@description('Deploy Azure API Management APIs (and deploy them to the APIC service)')
@metadata({
  azd: {
    type: 'string'
  }
})
param deployAzureAPIMtoAPIC bool

@description('Deploy SAP API Management APIs to the APIC service')
@metadata({
  azd: {
    type: 'string'
  }
})
param deploySapAPIMtoAPIC bool

@description('SAP OData backend endpoint url for Azure API Management')
@metadata({
  azd: {
    type: 'string'
  }
})
param sapBackendEndpoint string

@description('SAP OData backend api key url for Azure API Management')
@secure()
@metadata({
  azd: {
    type: 'string'
  }
})
param sapBackendApiKey string

@description('SAP API Management Token Url')
@metadata({
  azd: {
    type: 'string'
  }
})
param sapApimTokenUrl string

@description('SAP API Management Discovery Url')
@metadata({
  azd: {
    type: 'string'
  }
})
param sapApimDiscoveryUrl string

@description('SAP API Management client id')
@secure()
@metadata({
  azd: {
    type: 'string'
  }
})
param sapApimClientId string

@description('SAP API Management client secret')
@secure()
@metadata({
  azd: {
    type: 'string'
  }
})
param sapApimSecret string

@description('Azure API Management SKU.')
@allowed(['StandardV2', 'Developer', 'Premium'])
param apimSku string = 'StandardV2'
param apimSkuCount int = 1

@description('Azure API Center SKU.')
@allowed(['None'])
param apicSku string = 'None'

//Leave blank to use default naming conventions
param resourceGroupName string = ''
param apimServiceName string = ''
param apicServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param apimIdentityName string = ''
param apicIdentityName string = ''
param keyVaultName string = ''
param myPrincipalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var tags = { 'azd-env-name': environmentName }
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var sapApiKeySecretName = 'sap-api-key'
var sapClientIdSecretName = 'sap-apim-client-id'
var sapSecretSecretName = 'sap-apim-secret'
var sapAppMetadataSchema = loadTextContent('./core/apic/metadata/sap-app-metadata-schema.json')
var rootUrl = !empty(sapApimDiscoveryUrl) ? split(sapApimDiscoveryUrl, '/apidiscovery')[0] : ''
var sapManagementPortalUrl = !empty(rootUrl) ? '${rootUrl}/shell/homepage' : ''
var sapDeveloperPortalUrl = !empty(rootUrl) ? '${rootUrl}/shell/configure' : ''
var apimOpenAPISpecFileLocation = 'infra/core/apic/openapi/API_BUSINESS_PARTNER.json'
// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Add resources to be provisioned below.
module managedIdentityApim './core/security/managed-identity.bicep' = if(deployAzureAPIMtoAPIC){
  name: 'managed-identity-apim'
  scope: rg
  params: {
    name: !empty(apimIdentityName) ? apimIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-apim'
    location: location
    tags: tags
  }
}

module managedIdentityApic './core/security/managed-identity.bicep' = {
  name: 'managed-identity-apic'
  scope: rg
  params: {
    name: !empty(apicIdentityName) ? apicIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-apic'
    location: location
    tags: tags
  }
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// Migrating API Management instance to stv2, which requires a public IP
var apimService = !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
module apimPip './core/networking/publicip.bicep' = if(apimSku != 'StandardV2' && deployAzureAPIMtoAPIC){
  name: 'apim-pip'
  scope: rg
  params: {
    name: '${apimService}-pip'
    location: location
    tags: tags
    fqdn:'${apimService}.${location}.cloudapp.azure.com'
  }
}

module apim './core/gateway/apim.bicep' = if(deployAzureAPIMtoAPIC) {
  name: 'apim'
  scope: rg
  params: {
    name: apimService
    location: location
    tags: tags
    sku: apimSku
    skuCount: apimSkuCount
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    managedIdentityName: managedIdentityApim.outputs.managedIdentityName
    apicManagedIdentityName: managedIdentityApic.outputs.managedIdentityName
  }
}

module sapApiService './core/gateway/apim-api.bicep' = if(deployAzureAPIMtoAPIC){
  name: 'sap-api'
  scope: rg
  params: {
    name: 'api-business-partner'
    displayName: 'SAP Business Partner API'
    path: 'api/sapbp'
    SpecUrl: 'https://raw.githubusercontent.com/azure-samples/azd-apic-sap/main/infra/core/gateway/odata/API_BUSINESS_PARTNER.edmx'
    apimServiceName: apim.outputs.apimServiceName
    apimLoggerName: apim.outputs.apimLoggerName
    keyVaultEndpoint: keyVault.outputs.keyVaultEndpoint
    sapKeyVaultSecretName: sapApiKeySecretName
    managedIdentityName: managedIdentityApim.outputs.managedIdentityName
    sapUri: sapBackendEndpoint
  }
}

module keyVault './core/security/keyvault.bicep' = {
  name: 'key-vault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: myPrincipalId
    apimManagedIdentityName: deployAzureAPIMtoAPIC ? managedIdentityApim.outputs.managedIdentityName : ''
    deployAzureAPIMtoAPIC: deployAzureAPIMtoAPIC 
  }
}

module sapApiKeyKeyVaultSecret './core/security/keyvault-secret.bicep' = if(deployAzureAPIMtoAPIC){
  name: 'sap-apikey-keyvault-secret'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    name: sapApiKeySecretName
    secretValue: sapBackendApiKey
  }
}

module sapApimClientIdKeyVaultSecret './core/security/keyvault-secret.bicep' = if(deploySapAPIMtoAPIC){
  name: 'sap-apim-clientid-keyvault-secret'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    name: sapClientIdSecretName
    secretValue: sapApimClientId
  }
}

module sapApimSecretKeyVaultSecret './core/security/keyvault-secret.bicep' = if(deploySapAPIMtoAPIC){
  name: 'sap-apim-secret-keyvault-secret'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    name: sapSecretSecretName
    secretValue: sapApimSecret
  }
}

module apic './core/apic/apic.bicep' = {
  name: 'apic'
  scope: rg
  params: {
    name: !empty(apicServiceName) ? apicServiceName : '${abbrs.apiCenterService}${resourceToken}'
    location: location
    tags: tags
    sku: apicSku
    managedIdentityName: managedIdentityApic.outputs.managedIdentityName
    principalId: myPrincipalId
  }
}

module sapApicEnvironment './core/apic/apic-environment.bicep' = if(deploySapAPIMtoAPIC){
  name: 'sap-apic-environment'
  scope: rg
  params: {
    name: 'sap-api-management'
    title: 'SAP API Management'
    description: 'SAP API Management instance (SAP Integration Suite trial)'
    kind: 'Development'
    developerPortalUri: sapDeveloperPortalUrl
    managementPortalUri: sapManagementPortalUrl
    environmentType: 'ApiGee API Management'
    apicWorkspaceName: apic.outputs.apicWorkspaceName
    apicServiceName: apic.outputs.apicServiceName
  }
}

module apimApicEnvironment './core/apic/apic-environment.bicep' = if(deployAzureAPIMtoAPIC){
  name: 'apim-apic-environment'
  scope: rg
  params: {
    name: 'azure-api-management'
    title: 'Azure API Management'
    description: 'Azure API Management instance (${apimSku})'
    kind: 'Development'
    developerPortalUri: apim.outputs.apimDeveloperPortalUrl
    managementPortalUri: apim.outputs.apimManagementPortalUrl
    environmentType: 'Azure API Management'
    apicServiceName: apic.outputs.apicServiceName
    apicWorkspaceName: apic.outputs.apicWorkspaceName
  }
}

// Prepared for future use
/*
module sapApicMetadata './core/apic/apic-metadata.bicep' = {
  name: 'sap-apic-metadata'
  scope: rg
  params: {
    name: 'SAP Metadata'
    assignedTo: [
      {
        deprecated: false
        entity: 'api' //('api', 'deployment', 'environment')
        required: false
      }
      {
        deprecated: false
        entity: 'environment' //('api', 'deployment', 'environment')
        required: false
      }
    ]
    metadataSchema: sapAppMetadataSchema
    apicServiceName: apic.outputs.apicServiceName
  }
}
 
module sapApicServiceApi './core/apic/apic-api.bicep' = if(deploySapAPIMtoAPIC){
  name: 'sap-apic-api'
  scope: rg
  params: {
    name: 'sap-gw-sample-basic'
    title: 'SAP_GW_SAMPLE_BASIC'
    description: 'SAP Gateway sample service hosted on public demo system SAP ES5. Get access here: https://developers.sap.com/tutorials/gateway-demo-signup.html'
    summary: 'OData sample service on ES5'
    kind: 'REST'
    contactName: 'n/a'
    contactEmail: 'noreply@microsoft.com'
    docsTitle: 'SAP Docs'
    docsDescription: 'SAP Documentation'
    docsUrl: 'https://help.sap.com/doc/saphelp_nw74/7.4.16/en-US/03/06f171ff1d40369fa294d11af0a364/frameset.htm'
    licenseName: 'SAP Trial License'
    licenseUrl: 'https://developers.sap.com/tutorials/gateway-demo-signup.html'
    versionName: '1'
    versionTitle: '1'
    versionLifecycle: 'Design'
    definitionName: 'openapi'
    definitionTitle: 'OpenAPI'
    definitionDescription: 'OpenAPI definition of the SAP Gateway sample GWSAMPLE_BASIC'
    runtimeUri: sapRuntimeUrl
    deploymentName: 'v1-deployment'
    deploymentTitle: 'v1 Deployment'
    deploymentDescription: 'Initial deployment of the SAP Gateway sample GWSAMPLE_BASIC'
    apicWorkspaceName: apic.outputs.apicWorkspaceName
    apicEnvironmentName: sapApicEnvironment.outputs.apicEnvironmentName
    apicServiceName: apic.outputs.apicServiceName
  }
}
*/

module apimApicServiceApi './core/apic/apic-api.bicep' = if(deployAzureAPIMtoAPIC){
  name: 'apim-apic-api'
  scope: rg
  params: {
    name: 'api-business-partner'
    title: 'API_BUSINESS_PARTNER'
    description: 'Azure API Management API for SAP Business Partner OData backend'
    summary: 'OData sample on Azure API Management'
    kind: 'REST'
    contactName: 'n/a'
    contactEmail: 'noreply@microsoft.com'
    docsTitle: 'APIM Docs'
    docsDescription: 'APIM Documentation'
    docsUrl: 'https://docs.microsoft.com/en-us/azure/api-management/'
    licenseName: 'APIM License'
    licenseUrl: 'https://azure.microsoft.com/en-us/pricing/details/api-management/'
    versionName: 'v1'
    versionTitle: 'v1'
    versionLifecycle: 'Design'
    definitionName: 'openapi'
    definitionTitle: 'openapi'
    definitionDescription: 'OpenAPI definition of the SAP Business Partner API'
    runtimeUri: sapApiService.outputs.serviceApiUrl
    deploymentName: 'v1-deployment'
    deploymentTitle: 'v1 Deployment'
    deploymentDescription: 'Initial deployment of the APIM API'
    apicServiceName: apic.outputs.apicServiceName
    apicWorkspaceName: apic.outputs.apicWorkspaceName
    apicEnvironmentName: apimApicEnvironment.outputs.apicEnvironmentName
  }
}

// Add outputs from the deployment here
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output RESOURCE_GROUP_NAME string = rg.name
output AZURE_KEYVAULT_NAME string = keyVault.outputs.keyVaultName
output APIM_SERVICE_NAME string = deployAzureAPIMtoAPIC ? apim.outputs.apimServiceName : ''
output APIM_RESOURCE_ID string = deployAzureAPIMtoAPIC ? apim.outputs.apimResourceId : ''
output APIC_SERVICE_NAME string = apic.outputs.apicServiceName
output APIC_SAP_ENVIRONMENT_NAME string = deploySapAPIMtoAPIC ? sapApicEnvironment.outputs.apicEnvironmentName : ''
output APIC_APIM_ENVIRONMENT_NAME string = deployAzureAPIMtoAPIC ? apimApicEnvironment.outputs.apicEnvironmentName : ''
output APIC_WORKSPACE_NAME string = apic.outputs.apicWorkspaceName
output SAP_APIM_TOKEN_URL string = deploySapAPIMtoAPIC ? sapApimTokenUrl : ''
output SAP_APIM_DISCOVERY_URL string = deploySapAPIMtoAPIC ? sapApimDiscoveryUrl : ''
output SAP_CLIENTID_KV_SECRET_NAME string = deploySapAPIMtoAPIC ? sapClientIdSecretName : ''
output SAP_SECRET_KV_SECRET_NAME string = deploySapAPIMtoAPIC ? sapSecretSecretName : ''
output DEPLOY_SAP_APIM_TO_APIC bool = deploySapAPIMtoAPIC
output DEPLOY_AZURE_APIM_TO_APIC bool = deployAzureAPIMtoAPIC

output APIM_SAP_OPENAPI_SPEC_FILE string = deployAzureAPIMtoAPIC ? apimOpenAPISpecFileLocation : ''
output APIM_SAP_API_NAME string = deployAzureAPIMtoAPIC ? apimApicServiceApi.outputs.apicApiName : ''
output APIM_SAP_VERSION_NAME string = deployAzureAPIMtoAPIC ? apimApicServiceApi.outputs.apicApiVersionName : ''
output APIM_SAP_DEFINITION_NAME string = deployAzureAPIMtoAPIC ? apimApicServiceApi.outputs.apicApiDefinitionName : ''
