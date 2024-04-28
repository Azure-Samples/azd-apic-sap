#run az login and set correct subscription if needed
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

# Loop through the APIs discovered and import them into APIC
$discoveryResponse.value | ForEach-Object {
    $name = $_.name
    $version = "v$($_.version)"
    $url = $_.apiDefinitions[0].url
    $runtimeUri = $_.entryPoints[0].url
    $apiName = ($name -replace "_", "").ToLower()
    # $releaseStatus = $_.releaseStatus
    $summary = $_.summary
    $description = $_.description
    Write-Host "API Discovered: $name - $url"
    Write-Host "Retrieving API definition, saving as file"
    $resourceResponse = Invoke-RestMethod -Uri $_.apiDefinitions[0].url -Headers $headers -Method Get -ContentType "application/json"
    $jsonString = $resourceResponse | ConvertTo-Json -Depth 50
    $newJsonFilePath = "infra\core\apic\openapi\sap\$name.json"
    $jsonString | Out-File -FilePath $newJsonFilePath -Force
    # Output the file path for confirmation
    Write-Output "OpenAPI Spec saved to: $newJsonFilePath"
    # Import API into APIC
    Write-Host "Checking if API already exists in APIC..."
    $api = az apic api list -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --output json | ConvertFrom-Json
    $matchingApi = $api | Where-Object { $_.name -eq $apiName }
    if (!$matchingApi) {
        Write-Host "API not found, importing..."
        # AZ CLI METHOD
        # az apic api register -g $azdenv.RESOURCE_GROUP_NAME -s $azdenv.APIC_SERVICE_NAME --api-location $newJsonFilePath --environment-name $azdenv.APIC_SAP_ENVIRONMENT_NAME
        # Write-Host "Import completed"

        # SMAPI METHOD
        # Obtain an access token
        $accessToken = az account get-access-token --query accessToken -o tsv

        # Add API
        $apiUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)?api-version=2024-03-01"
        $apiBody = @{
            properties = @{
                title = "$name"
                summary = "$summary"
                description = "$description"
                kind = "rest"
                lifecycleStage = "design"
                license = @{
                    name = "SAP trial"
                    url = "https://developers.sap.com/tutorials/gateway-demo-signup.html"
                    identifier = "trial"
                }
                externalDocumentation = @( 
                    @{
                        title = "SAP Docs"
                        url = "https://help.sap.com/doc/saphelp_nw74/7.4.16/en-US/03/06f171ff1d40369fa294d11af0a364/frameset.htm"
                    }
                )
                contacts = @(
                    @{
                        name = "n/a"
                        url = "https://microsoft.com"
                        email = "noreply@microsoft.com"
                    }
                )
            }
        } | ConvertTo-Json -Depth 5
        $responseApi = Invoke-RestMethod -Uri $apiUrl -Method Put -Headers @{Authorization="Bearer $accessToken"} -Body $apiBody -ContentType "application/json"
        if ($responseApi) {
            Write-Host "API added successfully"
        } 
        else 
        {
            Write-Host "Failed to add API"
        }
        
        # Add version
        $versionUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/versions/$($version)?api-version=2024-03-01"
        $versionBody = @{
            properties = @{
                title = "$version"
                lifecycleStage = "design"
            }
        } | ConvertTo-Json -Depth 5
        $responseVersion = Invoke-RestMethod -Uri $versionUrl -Method Put -Headers @{Authorization="Bearer $accessToken"} -Body $versionBody -ContentType "application/json"
        if ($responseVersion) {
            Write-Host "Version added successfully"
        } 
        else 
        {
            Write-Host "Failed to add Version"
        }

        # Add definition
        $defintion = "openapi"
        $definitionUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/versions/$($version)/definitions/$($defintion)?api-version=2024-03-01"
        $definitionBody = @{
            properties = @{
                title = "$defintion"
                description = "SAP OpenAPI 3.0.0"
            }
        } | ConvertTo-Json -Depth 5
        $responseDefinition = Invoke-RestMethod -Uri $definitionUrl -Method Put -Headers @{Authorization="Bearer $accessToken"} -Body $definitionBody -ContentType "application/json"
        if ($responseDefinition) {
            Write-Host "Definition added successfully"
        } 
        else 
        {
            Write-Host "Failed to add Definition"
        }

        # Import Spec
        $specUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/versions/$($version)/definitions/$($defintion)/importSpecification?api-version=2024-03-01"
        $specBody = @{
            format = "inline"
            value = "$jsonString"
            specification = @{
                name = "openapi"
                version = "3.0.0"
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

        # Define the REST API URL for adding a deployment
        $deploymentName = "$($version)-deployment"
        $deploymentUrl = "https://management.azure.com/subscriptions/$($azdenv.AZURE_SUBSCRIPTION_ID)/resourceGroups/$($azdenv.RESOURCE_GROUP_NAME)/providers/Microsoft.ApiCenter/services/$($azdenv.APIC_SERVICE_NAME)/workspaces/$($azdenv.APIC_WORKSPACE_NAME)/apis/$($apiName)/deployments/$($deploymentName)?api-version=2024-03-01"
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
        } | ConvertTo-Json -Depth 10
        $responseDeployment = Invoke-RestMethod -Uri $deploymentUrl -Method Put -Headers @{Authorization="Bearer $accessToken"} -Body $deploymentBody -ContentType "application/json"

        if ($responseDeployment) {
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