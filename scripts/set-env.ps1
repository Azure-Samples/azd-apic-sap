#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    Write-Host "Setting MY_USER_ID..."
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal
    Write-Host "Done"
    Write-Host "Updating APIC extension..."
    $apicExtension= az extension list --query "[?name=='apic-extension'].name" -o tsv  
    if (!$apicExtension) {
        Write-Host "APIC extension not found... Installing..."
        az extension add -n apic-extension
    }
    else {
        Write-Host "APIC extension found... Updating..."
        az extension update --name apic-extension
    }
    Write-Host "Done"
}


