#
#
#           LOGO HERE
#
#
# Copyright (C) [Company Name Here] - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary and confidential
# Written by Francisco Brito
# February 2021

<#
    .SYNOPSIS
        This script will run a test and send the results to Azure Monitor as a custom metric
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$appID,
    [Parameter(Mandatory = $true)]
    [string]$tenID,
    [Parameter(Mandatory = $true)]
    [string]$appSecret
)

#region Import Library

# dot-source library script
# notice that you need to have a space
# between the dot and the path of the script
. C:\support\Template\library.ps1 #TODO - Change this path

#endregion

function Run-Test(){

    <#
    .SYNOPSIS
    This function will ....
    .DEION

    .EXAMPLE
    Run-Test()
    #>

    # Coment
    $testArray = @('') # TODO - Change the name of the variable

    # Array to store the results
    $results = [System.Collections.ArrayList]::new()
    # [void]$results.Add('1')

    Write-Host "Checking ... >>>>> "(Get-Date).tostring()
    Write-Host

    # Coment

    # CODE HERE

    if ($results.Contains('2'))
    {
        Return 2
    }
    else
    {
        Return 1
    }

}

####################################################

$logRequestUris = $true;
$logHeaders = $false;
$logContent = $true;
$eventID = [System.IO.Path]::GetFileNameWithoutExtension((& { $myInvocation.ScriptName }))
$logFile = "C:\support\Logs\$eventID.txt" # TODO - Change this variable value

####################################################

Start-Transcript -Path $logFile | Out-Null

Write-Host
Write-Host
Write-Host "Beginning Scritps Execution >>>>> "(Get-Date).tostring()
Write-Host
Write-Host

#region Authentication

$global:authToken = Get-AuthToken -appID $appID -tenID $tenID -appSecret $appSecret

#endregion

if($authToken -ne $null){

    SendMetrics($eventID)

}
else{
    Write-Host "Requisition of an OAuth 2.0 from Microsoft Identity Platform token has failed" -ForegroundColor Red
    Write-Host "Script will be terminated" -ForegroundColor Red
}

Stop-Transcript

GenerateLogFile -logFile $logFile -eventID $eventID