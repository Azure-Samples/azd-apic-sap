#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {
    Write-Host "Setting MY_USER_ID..."
    $myPrincipal = az ad signed-in-user show --query "id" -o tsv
    azd env set MY_USER_ID $myPrincipal
    Write-Host "Done"
    Write-Host "Updating APIC extension to the latest..."
    $apicExtension= az extension list --query "[?name=='apic-extension'].name" -o tsv  
    if (!$apicExtension) {
        Write-Host "APIC extension not found... skipping deletion"
    }
    else {
        az extension remove --name apic-extension
    }
    #$pathExtension="./extensions/apic_extension-1.0.0b4-py3-none-any.whl"
    #az extension add --source $pathExtension --yes
    az extension add -n apic-extension
    Write-Host "Done"
}


