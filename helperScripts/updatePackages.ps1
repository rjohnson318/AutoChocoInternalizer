# This script will attempt to download and prepare all packages that are contained in the
# packages.csv file.

# Step 1: Download all of the packages from chocolatey repo to `packageDownloads`
# Step 2: Internalize all of the packages:
    # 2.X: Make a folder for each package in the internalizing folder
    # 2.1a: If prepType none:
        # do nothing to the package
    # 2.1b: If prepType download or custom(ie not none): (though custom could be different)
        # 2.1a.1: rename extentions to zip and unzip
        # 2.1a.2: Delete rels, package, and content types files
        # 2.1a.3: Download the installer files being referenced by url
        # 2.1a.4: Replace url with reference to local MyChocoFilesLocation
        # 2.1a.5 

############################################### Functions ###############################################
Function Start-Download($Url, $Destination, $Package) {
    $fileName = ($Url -split '/')[-1]
    $Destination = Join-Path (Get-Item $Destination).FullName $fileName
    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -TransferType Download -ErrorAction Stop
    } catch {
        try {
            Write-Host "`t`t`tPrimary download technique failed, attempting secondary download mode with WebClient." -ForegroundColor Yellow
            (New-Object System.Net.WebClient).DownloadFile("$Url", "$Destination")
        } catch {
            Write-Host "There was an error downloading from '$Url' to '$Destination'`n`tError Message: $($Error[0].Exception.Message)" -ForegroundColor Red
            $Package.errorMessage = "$($Error[0].Exception.Message)"
        }
    }
}

Function Update-Automatically($Package) {
    $packageZipName = "$($package.nupkgName.substring(0, $package.nupkgName.length - 6)).zip"
    $packageFolderLocation = "../2.unpackedPackages/$($package.packageID)"
    $referencedURLs = @()
    $fileLocations = ""

    # Create folder package in unpackedPackages folder
    if (!(Test-Path $packageFolderLocation)) {
        Write-Host "`n`t`tUnpacking folder for $($package.packageID) does not exist. Creating it."
        mkdir $packageFolderLocation | Out-Null
    }

    Write-Host "`n`t`tMoving '../1.packageDownloads/$($package.nupkgName)' to '$packageFolderLocation' with new name '$packageZipName'"
    Copy-Item "../1.packageDownloads/$($package.nupkgName)" -Destination "$packageFolderLocation/$packageZipName"

    # Unzipping and deleting unessesary files (including the zip)
    Write-Host "`n`t`tUnzipping $packageZipName and then deleting it and other unessesary files."
    Expand-Archive -Path "$packageFolderLocation/$packageZipName" -DestinationPath $packageFolderLocation -Force
    Remove-Item -Path "$packageFolderLocation/$packageZipName" -Force
    Remove-Item -Path "$packageFolderLocation/_rels" -Force -Recurse
    Remove-Item -Path "$packageFolderLocation/package" -Force -Recurse
    Remove-Item -Path "$packageFolderLocation/``[Content_Types``].xml" -Force
    
    # Download Referenced URLs
    Write-Host "`n`t`tDownloading referenced urls."
    if (!(Test-Path "../4.installerDownloads/$($package.packageID)")) {
        Write-Host "`n`t`t`tInstaller Download folder for $($package.packageID) does not exist. Creating it."
        mkdir "../4.installerDownloads/$($package.packageID)" | Out-Null
    }

    # Setting default downloadUrlRegex if not specified
    if ($package.downloadUrlRegex -eq "") {
        $package.downloadUrlRegex = "(?<=(`"|'))http.*(?=(`"|'))"
    }
    
    $referencedURLs += Get-Content "$packageFolderLocation/tools/chocolateyinstall.ps1" | Select-String -Pattern $package.downloadUrlRegex | % {$_.matches.groups[0]}
    
    # Downloading referenced URLs and creating a reference link to where the installers will be stored.
    $i = 0
    foreach ($url in $referencedURLs) {
    #for ($i = 0; $i -lt $referencedURLs.Count; $i++) {
        Write-Host "`n`t`t`tFound and now downloading: $url"
        $startTime = Get-Date
        Start-Download -Url $url -Destination "../4.installerDownloads/$($package.packageID)/" -Package $package
        Write-Host "`t`t`t`tDone. Time taken: $((Get-Date).Subtract($startTime).Seconds) second(s)." -ForegroundColor Green

        $fileLocations += "`$fileLocation$i = (Get-WmiObject Win32_OperatingSystem).getPropertyValue(`"SystemDrive`") + `"\installerDownloads\$($package.packageID)\$(($url -split '/')[-1])`"`r`n"
        $i++
    }

    Write-Host "`n`t`tEditing chocolateyInstall.ps1 file."
    # Adding Installer MyChocoFiles location to the top of the chocolateyInstall.ps1 file
    $fileLocations + (Get-Content "$packageFolderLocation/tools/chocolateyinstall.ps1" -Raw) | Set-Content "$packageFolderLocation/tools/chocolateyinstall.ps1"
    
    # Replacing url in main body with variable
    # This is close but doesnt increment i: #(Get-Content "$packageFolderLocation/tools/chocolateyinstall.ps1") -replace "(?<=(`"|'))http.*(?=(`"|'))", "fileLocation$(($i++))" | Set-Content "$packageFolderLocation/tools/chocolateyinstall.ps1"    # There is definatly an elegent way to do this but im tired.
    $i = 0
    (Get-Content "$packageFolderLocation/tools/chocolateyinstall.ps1") | ForEach-Object {
        $_ -replace "(`"|')$($package.downloadUrlRegex)(`"|')", "`$fileLocation$i"
        if ($_ -match $package.downloadUrlRegex) { $i++ }
    } | Set-Content "$packageFolderLocation/tools/chocolateyinstall.ps1"
}

Function Get-RedirectedUrl($url, $Package) {
    try {
        $request = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction Ignore
        if($request.StatusDescription -eq 'found'){
            $request.Headers.Location
        }
    } catch {
        Write-Host "There was an error in Get-RedirectedUrl function while using url:`"$url`".`n`tError Message: $($Error[0].Exception.Message)" -ForegroundColor Red
        $Package.errorMessage = "$Error[0].Exception.Message"
    }
}

############################################### Settings ###############################################
$forceAllDownloads = $false
$ignoreErrorStates = $false

############################################### Main Code ###############################################
Import-Module BitsTransfer
$packages = Import-Csv "../packages.csv"

# Step 1: Download all packages
Write-Host "`nBeginning the download of all packages."
foreach ($package in $packages) {
    if ($package.disabled -eq "true") { continue }
    if ($package.errorMessage -ne "" -and !$ignoreErrorStates) { 
        Write-Host "`n`tSkipping download for $($package.packageID) because it is in an error state." -ForegroundColor Red
        continue
    }

    $url = Get-RedirectedUrl -url "https://chocolatey.org/api/v2/package/$($package.packageID)/$($package.versionNumber)" -Package $package
    $nupkgName = ($url -split '/')[-1]
    $startTime = Get-Date

    if ($forceAllDownloads -or !(Test-Path "../1.packageDownloads/$nupkgName")) {
        Write-Host "`n`tDownloading $nupkgName from $url"
        Start-Download -Url $url -Destination "../1.packageDownloads/" -Package $package 
        Write-Host "`t`tDone. Time taken: $((Get-Date).Subtract($startTime).Seconds) second(s)." -ForegroundColor Green

        # Update the package (nupkg) file name in the csv
        $package.nupkgName = $nupkgName
    } else {
        Write-Host "`n`t$nupkgName already exists. Not downloading." -ForegroundColor Yellow
    }
}

# Prepare Packages:
Write-Host "`nBeginning package prep for all packages."
foreach ($package in $packages) {
    if ($package.disabled -eq "true") { continue }
    if ($package.errorMessage -ne "" -and !$ignoreErrorStates) { 
        Write-Host "`n`tSkipping package prep for $($package.packageID) because it is in an error state."
        continue
    }

    Write-Host "`n`tPreping: $($package.packageID)"

    if ($package.prepType -eq "none") { # prep type none. Just move the nupkg to repackedPackages folder
        Write-Host "`n`t`tThe package prep type is none. No changes are required."
        Write-Host "`n`t`tMoving '../1.packageDownloads/$($package.nupkgName)' to '../3.repackedPackages/$($package.nupkgName)'" -ForegroundColor Green
        Copy-Item "../1.packageDownloads/$($package.nupkgName)" -Destination "../3.repackedPackages/$($package.nupkgName)"
    } elseif ($package.prepType -eq "auto" ) { # prep type auto. Will attemp to automatically update the package.
        Write-Host "`n`t`tThe package prep type is auto."
        Update-Automatically -Package $package
    } elseif ($package.prepType -eq "custom") { # prep Type custom. Attempting to find and use the packages custom updater.
        Write-Host "`n`t`tThe package prep type is custom. Attempting to find and use the package's custom updater." 
    } else {
        Write-Host "!!!!!!!!!!!!!!!!!!!!! INVALID PREP TYPE FOR PACKAGE $($package.packageID) !!!!!!!!!!!!!!!!!!!!!" -ForegroundColor Red
    }
}

# Packing up all packages
Write-Host "`nPacking up the packages.`n"
Invoke-Expression -Command "./packUp.ps1"

# Update the csv file with updated info
$packages | Export-Csv -Path "../packages.csv" -NoTypeInformation
Write-Host "`nDone Updating Packages.`n"