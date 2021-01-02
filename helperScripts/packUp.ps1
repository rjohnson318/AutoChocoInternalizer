# This script will automatically pack all packages that are contained in the super directories
# listed in the $superDirectoriesToPack variable. It will not recursivly search for packages.
# It will only assume the individual folders in the super directories are their own packages.

$repackDirectory = (Get-Item "../3.repackedPackages").FullName
$repackDirectory = $repackDirectory.Substring(0, $repackDirectory.Length)

# Importing CSV data for smarter package manipulation
$packages = Import-Csv "../packages.csv"

# Checkin if Chocolatey is installed and running installer if it is not
try{
    choco config get cacheLocation -y -r
}catch{
    Write-Output "Chocolatey not detected, trying to install now"
    Invoke-Expression -Command "./installChocoCommand.ps1"
}

# Pack each package
foreach ($package in $packages) {
    if ($package.disabled -eq "true") { continue }
    Write-Output ("`n- Packing: {0}" -f $package.nupkgName)

    if ($package.errorState -ne $null) {
        Write-Host "`n`tSkipping pack-up for $($package.packageID) because it is in an error state." -ForegroundColor Red
        continue
    }
    if ($package.prepType -eq "none") { # Skip if there is no package to pack
        Write-Host "`n`tSkipping pack-up for $($package.packageID) because its prepType is none and doesnt need to be packed." -ForegroundColor Green
        continue
    }
    if ($package.prepType -eq "custom") { # This is temporary since custom prep type is not implimented yet.
        Write-Host "`n`tSkipping pack-up for $($package.packageID) because its prepType is custom." -ForegroundColor Green
        continue
    }

    $directory = (Get-Item "../2.unpackedPackages/$($package.packageID)").FullName
    Write-Output ("`n`tDirectory: {0}`n`tchoco pack output:" -f $directory)
    
    Set-Location $directory
    choco pack --out "$repackDirectory" -y -r

    # Test if the nupkg was in fact packed by testing for it
    if(!(Test-Path -Path "$(Join-Path $repackDirectory $package.nupkgName)")) {
        Write-Host "`n`tThere was an error while trying to pack-up $(Join-Path $directory $package.nupkgName)." -ForegroundColor Red
        $package.errorMessage = "Error while packing."
    }

    Push-Location $PSScriptRoot # Returning to the original script directory
}

# Push-Location $PSScriptRoot # Returning to the original script directory

Write-Output "`n`nList of packages that attempted packing:"
foreach ($package in $packages) {
    Write-Output ("`t- {0}" -f $package.packageID)
}

# Update the csv file with updated info
$packages | Export-Csv -Path "../packages.csv" -NoTypeInformation