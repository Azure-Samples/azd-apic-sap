param name string
param metadataSchema string
param apicServiceName string
param assignedTo array
//{
//  deprecated: bool
//  entity: 'string'
//  required: bool
//}


resource apic 'Microsoft.ApiCenter/services@2024-03-01' existing = {
  name: apicServiceName
}

resource apicMetadata 'Microsoft.ApiCenter/services/metadataSchemas@2024-03-01' = {
  name: name
  parent: apic
  properties: {
    assignedTo: assignedTo
    schema: metadataSchema
  }
}

output apicMetadataName string = apicMetadata.name
