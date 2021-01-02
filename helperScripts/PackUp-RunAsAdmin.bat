:: This script helps the pack up all the packages as Admin
:: !!!!! This must be run as Admin !!!!!
:: This script is nessesary to get around the powershell Execution Policy and simplify installation by limiting user interaction.
@echo off

:: Checking Admin Permissions
echo Administrative permissions required. Detecting permissions...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Success: Administrative permissions confirmed.
) else (
    echo Failure: Current permissions inadequate.
    timeout 10
    EXIT /b 1
)

:: Returning the active directory to the directory the script was run from.
:: When running cmd files as admin they default to a system folder. This mitigates that.
pushd %~dp0

:: Running the powershell script that contains the chocolatey installation script.
powershell.exe -executionpolicy bypass -File ".\packUp.ps1"

timeout 15