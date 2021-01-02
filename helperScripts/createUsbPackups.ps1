$ignoreErrorStates = $false

Write-Host "Beginning USB Packup process.`n"

$usbPackupsFolder = (Get-Item "../5.usbPackups").FullName

if ($args.count -eq 0) {
    Write-Host "The selected package classification to pack up has not been specified or was 'all' and thus all found classifications will be packed.`n"
} else {
    Write-Host "The package classifications that will attempt packing are:"
    foreach($classification in $args) {
        Write-Host "`t- $classification"
    }
}
Write-Host "" # Addes a `n

# Remove existing usbPackup folders for the selected package classifications
foreach ($classification in $args) {
    if (Test-Path (Join-Path $usbPackupsFolder $classification)) {
        Write-Host "Emptying existing usbPackup folder for '$classification'.`n"
        Remove-Item (Join-Path $usbPackupsFolder $classification)
        mkdir (Join-Path $usbPackupsFolder $classification) | Out-Null
    }
}

$packages = Import-Csv "../packages.csv"

foreach($package in $packages) {
    if ($package.disabled -eq "true") { continue }

    if ($args.Contains($package.packageClassification)) {
        if ($package.errorMessage -ne "" -and !$ignoreErrorStates) { 
            Write-Host "Skipping $($package.packageID) because it is in an error state." -ForegroundColor Red
            continue
        }

        Write-Host "Packing up $($package.packageID) into classification $($package.packageClassification)."
    }
}