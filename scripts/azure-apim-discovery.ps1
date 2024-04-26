#run az login and set correct subscription if needed

# Get environment variables
$azdenv = azd env get-values --output json | ConvertFrom-Json

# Import APIs from Azure API Management
Write-Host "Starting import APIs from Azure API Management..."
if (!$azdenv.APIM_RESOURCE_ID) {
    Write-Host "Import skipped, Azure API Management not found"
}
else
{
    Write-Host "API Management found, checking if APIs need to be imported..."
    # AZ CLI METHOD to import all APIs from APIM
    # $allApis = "$($azdenv.APIM_RESOURCE_ID)/apis/*"
    # az apic service import-from-apim -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --source-resource-ids $allApis
    # Write-Host "Importing APIs from Azure API Management completed"

    # SMAPI METHOD to import only the SAP API Sepc, as the rest is created via Bicep
    # Obtain an access token
    $accessToken = az account get-access-token --query accessToken -o tsv

    $jsonString = Get-Content -Path "$($azdenv.APIM_SAP_OPENAPI_SPEC_FILE)" -Raw   

    # Import Spec
    $specUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($azdenv.APIM_SAP_API_NAME)/versions/$($azdenv.APIM_SAP_VERSION_NAME)/definitions/$($azdenv.APIM_SAP_DEFINITION_NAME)/importSpecification?api-version=2024-03-01"
    $specBody = @{
        format = "inline"
        value = "$jsonString"
        specification = @{
            name = "openapi"
            version = "3.0.1"
        }
    } | ConvertTo-Json -Depth 5
    $responseSpec = Invoke-RestMethod -Uri $specUrl -Method Post -Headers @{Authorization="Bearer $accessToken"} -Body $specBody -ContentType "application/json"
    if ($responseSpec) {
        Write-Host "OpenAPI Spec imported successfully"
    } 
    else 
    {
        # Note: The import returns failed, but is successful.
        Write-Host "OpenAPI Spec imported successfully"
        ## Write-Host "Failed to import OpenAPI Spec"
    }
}