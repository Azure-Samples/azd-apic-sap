#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1
if ($? -eq $true) {
    # Get environment variables
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    # Retrieve the Client ID & Secret from Azure Key Vault
    Write-Host "Retrieving SAP APIM Client ID & Secret from Azure Key Vault..."
    $keyVaultName = $azdenv.AZURE_KEYVAULT_NAME
    $clientIdSecretName = $azdenv.SAP_CLIENTID_KV_SECRET_NAME
    $clientSecretSecretName = $azdenv.SAP_SECRET_KV_SECRET_NAME
    $clientId = az keyvault secret show --name $clientIdSecretName --vault-name $keyVaultName --query value -o tsv
    $clientSecret = az keyvault secret show --name $clientSecretSecretName --vault-name $keyVaultName --query value -o tsv

    # Define the URLs for obtaining the token and for the resource you want to access
    $tokenUrl = $azdenv.SAP_APIM_TOKEN_URL
    $discoveryUrl = $azdenv.SAP_APIM_DISCOVERY_URL

    # Prepare the body for the token request
    $body = @{
        client_id = $clientId
        client_secret = $clientSecret
        grant_type = "client_credentials"
    }

    # Execute the POST request to get the token
    Write-Host "Getting token from SAP APIM..."
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    $token = $response.access_token

    # Prepare the header for the next REST call with the obtained token
    $headers = @{
        Authorization = "Bearer $token"
    }

    # Execute the GET request to Discovery all SAP APIM APIs
    Write-Host "Discovering APIs from SAP APIM..."
    $discoveryResponse = Invoke-RestMethod -Uri $discoveryUrl -Headers $headers -Method Get -ContentType "application/json"

    $discoveryResponse.value | ForEach-Object {
        $name = $_.name
        $version = $_.version
        $url = $_.apiDefinitions[0].url
        $runtimeUri = $_.entryPoints[0].url
        $apiName = ($name -replace "_", "").ToLower()
        Write-Host "API Discovered: $name - $url"
        Write-Host "Retrieving API definition, saving as file"
        $resourceResponse = Invoke-RestMethod -Uri $_.apiDefinitions[0].url -Headers $headers -Method Get -ContentType "application/json"
        $jsonString = $resourceResponse | ConvertTo-Json -Depth 10
        $newJsonFilePath = "infra\core\apic\openapi\$name.json"
        $jsonString | Out-File -FilePath $newJsonFilePath -Force
        # Output the file path for confirmation
        Write-Output "OpenAPI Spec saved to: $newJsonFilePath"
        # Import API into APIC
        Write-Host "Checking if API already exists in APIC..."
        $api = az apic api list -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --output json | ConvertFrom-Json
        $matchingApi = $api | Where-Object { $_.title -eq $name }
        if (!$matchingApi) {
            Write-Host "API not found, importing..."
            if (az apic api register -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --api-location $newJsonFilePath --environment-name $azdenv.APIC_SAP_ENVIRONMENT_NAME) 
            {
                Write-Host "API successfully imported"
            }
            else 
            {
                Write-Host "API import failed"
            }
            # Obtain an access token
            $accessToken = az account get-access-token --query accessToken -o tsv

            # Define the REST API URL for adding a deployment
            $deploymentName = "v$version-deployment"
            $deploymentUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/deployments/$($deploymentName)?api-version=2024-03-01"
            Write-Host "Adding deployment to API... $deploymentUrl"
            # Prepare the body for the deployment request
            $deploymentBody = @{
                properties = @{
                    title = "$deploymentName"
                    description = "$deploymentName"
                    environmentId = "/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/environments/$($azdenv.APIC_SAP_ENVIRONMENT_NAME)"
                    definitionId = "/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/versions/$($version)/definitions/openapi"
                    state = "active"
                    server = @{
                        runtimeUri = @(
                            [string]$runtimeUri
                        )
                    }
                }
            } | ConvertTo-Json -Depth 5
            Write-Host "Deployment Body: $deploymentBody"
            # Make the REST API call to add the deployment
            $response = Invoke-RestMethod -Uri $deploymentUrl -Method Put -Headers @{Authorization="Bearer $accessToken"} -Body $deploymentBody -ContentType "application/json"

            if ($response) {
                Write-Host "Deployment added successfully"
            } 
            else 
            {
                Write-Host "Failed to add deployment"
            }
        }
        else 
        {
            Write-Host "API already imported"
        }
    }
}