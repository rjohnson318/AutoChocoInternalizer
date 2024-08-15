# Import required modules
Import-Module BitsTransfer

# Global variables
$ignoreErrorStates = $false
$sourceFolder = (Get-Item "../3.repackedPackages").FullName
$usbPackupsFolder = (Get-Item "../5.usbPackups").FullName
$logFile = "createUsbPackups.log"

# Add logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

Write-Log "Beginning USB Packup process."

$usbPackupsFolder = (Get-Item "../5.usbPackups").FullName
Write-Log "USB Packups folder: $usbPackupsFolder"

# Get all unique classifications from the packages.csv
Write-Log "Importing packages from CSV file."
$packages = Import-Csv "../packages.csv"
Write-Log "Total packages found: $($packages.Count)"
$allClassifications = $packages | Select-Object -ExpandProperty packageClassification -Unique

# Determine which classifications to process
$classificationsToProcess = @()
if ($args.count -eq 0) {
    Write-Log "No specific package classification specified. All found classifications will be packed."
    $classificationsToProcess = $allClassifications
} else {
    Write-Log "Package classifications to pack:"
    foreach($classification in $args) {
        if ($allClassifications -contains $classification) {
            $classificationsToProcess += $classification
            Write-Log "- $classification"
        } else {
            Write-Log "Warning: Specified classification '$classification' not found in packages.csv" -Level "WARN"
        }
    }
}

# Create or empty usbPackup folders for all classifications
foreach ($classification in $allClassifications) {
    $classificationPath = Join-Path $usbPackupsFolder $classification
    if (!(Test-Path $classificationPath)) {
        New-Item -ItemType Directory -Path $classificationPath | Out-Null
        Write-Log "Created new directory: $classificationPath"
    } elseif ($classificationsToProcess -contains $classification) {
        Write-Log "Emptying existing usbPackup folder for '$classification'."
        Get-ChildItem -Path $classificationPath -Recurse | Remove-Item -Force -Recurse
    }
}

# Process packages
foreach($package in $packages) {
    if ($package.disabled -eq "true") {
        Write-Log "Skipping disabled package: $($package.packageID)" -Level "WARN"
        continue
    }

    if ($classificationsToProcess.Count -eq 0 -or $classificationsToProcess -contains $package.packageClassification) {
        if ($package.errorMessage -ne "" -and !$ignoreErrorStates) {
            Write-Log "Skipping $($package.packageID) because it is in an error state: $($package.errorMessage)" -Level "ERROR"
            continue
        }

        Write-Log "Starting to pack $($package.packageID) into classification $($package.packageClassification)."
        try {
            $sourcePackagePath = Join-Path $sourceFolder $package.nupkgName
            $destinationPath = Join-Path $usbPackupsFolder $package.packageClassification

            if (Test-Path $sourcePackagePath) {
                Copy-Item -Path $sourcePackagePath -Destination $destinationPath -Force
                Write-Log "Copied $($package.nupkgName) to $destinationPath"
            } else {
                throw "Source package not found: $sourcePackagePath"
            }

            Write-Log "Successfully packed $($package.packageID) into classification $($package.packageClassification)."
        }
        catch {
            Write-Log "Error packing $($package.packageID): $_" -Level "ERROR"
        }
    }
}

Write-Log "USB Packup process completed."
