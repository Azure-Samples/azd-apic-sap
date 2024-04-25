#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1
if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json
    
    # Import APIs from Azure API Management
    Write-Host "Starting import APIs from Azure API Management..."
    if (!$azdenv.APIM_RESOURCE_ID) {
        Write-Host "Import skipped, Azure API Management not found"
    }
    else {
        Write-Host "API found, importing..."
        if (az apic service import-from-apim -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --source-resource-ids "$($azdenv.APIM_RESOURCE_ID)/apis/*")
        {
            Write-Host "Azure API Management APIs successfully imported"
        }
        else 
        {
            Write-Host "Azure API Management APIs import failed"
        }
    }
}