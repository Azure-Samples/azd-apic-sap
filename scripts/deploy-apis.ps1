#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json
    
    if($azdenv.DEPLOY_AZURE_APIM_TO_APIC) {
        # Deploy Azure APIM APIs to APIC
        try {
            ./scripts/azure-apim-discovery.ps1
        }
        catch {
            Write-Host "Failed to deploy Azure APIM APIs to APIC"
            Write-Host $_.Exception.Message
            return
        }
        ./scripts/azure-apim-discovery.ps1
    }
    else {
        Write-Host "Skipping API Management APIs deployment to APIC"
    }

    if($azdenv.DEPLOY_SAP_APIM_TO_APIC) {
        # Deploy SAP APIM APIs to APIC
        try {
            ./scripts/sap-apim-discovery.ps1
        }
        catch {
            Write-Host "Failed to deploy SAP APIM APIs to APIC"
            Write-Host $_.Exception.Message
            return
        }
    }
    else {
        Write-Host "Skipping SAP API Management APIs deployment to APIC"
    }

    Write-Host "Deployment completed"
}