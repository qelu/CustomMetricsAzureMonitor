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
        Library
#>

function GenerateLogFile(){

    param (
        [Parameter(Mandatory = $true)]
        [string]$logFile,
        [Parameter(Mandatory = $true)]
        [string]$eventID
    )

    <#
    .SYNOPSIS
    This function is used to create a Log file for debugging the script execution
    .DEION
    Saves the information from the file created from Start-Transcript to a new file and deletes the original in order to hide sensitive information
    .EXAMPLE
    GenerateLogFile($logFile, $eventID)
    #>


    $newLog = "C:\support\Logs\$eventID.log"

    $MultilineComment = @'
#
#
#       LOGO HERE
#
#


'@

    if (!(Test-Path $newLog))
    {
        $fileName = $eventID+".log"
        New-Item -path C:\support\Logs\ -name $fileName -type "file" # TODO-Change the path name to a variable

        $MultilineComment -f 'string' | Out-File $newLog
    }
    else
    {
        Clear-Content $newLog

        $MultilineComment -f 'string' | Out-File $newLog
    }

    $content = Get-Content $logFile -ReadCount 3 | Select -Skip 6

    $log = $content | Add-Content $newLog

    Remove-Item $logFile -Force

}

####################################################

function Get-AuthToken {

    param (
        [Parameter(Mandatory = $true)]
        [string]$appID,
        [Parameter(Mandatory = $true)]
        [string]$appSecret,
        [Parameter(Mandatory = $true)]
        [string]$tenID
    )
    <#
    .SYNOPSIS
    This function is used to retrieve an OAuth 2.0 authorization token from Microsoft identity platform
    .DEION
    The function authenticates with Microsoft identity platform using the App Registration (AppID, AppSecret) created on Azure
    .EXAMPLE
    Get-AuthToken -appID [appID] -appSecret [appSecret] -tenID [tenID]
    #>

    Write-Host "Getting AuthToken >>>>> "(Get-Date).tostring()
    Write-Host

    $client_id = $appID
    $client_secret = $appSecret
    $tenant_id = $tenID

    $resource = "https://monitoring.azure.com/"
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"

    try{
        $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
        Write-Host "AuthToken generated successfully >>>>> "(Get-Date).tostring()
        Write-Host

        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $response.access_token
            'ExpiresOn'=$response.expires_on
        }

        return $authHeader
    }
    catch
    {
        Write-Host "An Error as occurred" -ForegroundColor Red
        Write-Host "Token Generation was not successful" -ForegroundColor Red

        return $null
    }
}

####################################################

function Get-ResourceData(){

    <#
    .SYNOPSIS
    This function is used to retrieve a JSON with information about {$env:computername} from Azure using AZ CLI so that we can extract it's resourceID and location
    .DEION
    Retrieves a JSON with information about {$env:computername} from Azure using the App Registration (AppID, AppSecret) created on Azure
    .EXAMPLE
    Get-ResourceData
    #>

    Write-Host "Logging in to Azure CLI >>>>> "(Get-Date).tostring()
    Write-Host

    # Log in Azure with App Registration credentials
    az login --service-principal -u $appID -p $appSecret --tenant $tenID | Out-Null

    Write-Host "Login successful >>>>> "(Get-Date).tostring()
    Write-Host

    Write-Host "Getting $env:computername information from Azure  >>>>> "(Get-Date).tostring()
    Write-Host

    # Get a JSON with information about {$env:computername} from Azure
    $json = az resource list --name $env:computername | ConvertFrom-Json

    if($json -ne "")
    {
        Write-Host "Done >>>>> "(Get-Date).tostring()
        Write-Host
        az logout
        return $json
    }
    else
    {
        Write-Host "Could not get $env:computername information from Azure  >>>>> "(Get-Date).tostring()
        Write-Host
        az logout
        return $emptyJson
    }
}

####################################################

function CloneObject($object){

    <#
    .SYNOPSIS
    This function is used to clone objects
    .DEION
    This function is used to clone objects
    .EXAMPLE
    CloneObject($object)
    #>

    $stream = New-Object IO.MemoryStream;
    $formatter = New-Object Runtime.Serialization.Formatters.Binary.BinaryFormatter;
    $formatter.Serialize($stream, $object);
    $stream.Position = 0;
    $formatter.Deserialize($stream);
}

####################################################

function SendMetrics($eventID){

    <#
    .SYNOPSIS
    This function will retrieve a JSON from the Get-MetricsBody function with the information required to create a custom metric on Azure Monitor and
    send that information to Azure Monitor via Azure Monitor REST API interface
    .DEION
    Sends the results of the Run-Tests function as a custom metric to Azure Monitor via Azure Monitor REST API interface
    .EXAMPLE
    SendMetrics()
    #>

    # Get Json file with the Alert definition
    $metricsBody = Get-MetricsBody($eventID)

    # Send Metrics to Azure Monitor
    $metrics = MakePostRequest ($metricsBody);

}

####################################################

function MakePostRequest($metricsBody){

    <#
    .SYNOPSIS
    This function will make a POST request to the uri defined in $uri
    .DEION
    Makes a POST request to $uri.
    .EXAMPLE
    MakePostRequest($metricsBody)
    .NOTES
    In case of this script the uri will be from the Azure Monitor REST API interface.
    $location will be the location of {$env:computername} on Azure
    $resourceID will be the resource ID of {$env:computername} on Azure
    #>

    $resourceData = Get-ResourceData

    # Exit function if $resourceData is null
    if($resourceData -ne $null)
    {

        $location = $resourceData.location
        $resourceID = $resourceData.id

        $uri = "https://$location.monitoring.azure.com$resourceID/metrics";
        $request = "POST $uri";

        $clonedHeaders = CloneObject $authToken;
        $clonedHeaders["content-length"] = $metricsBody.Length;
        $clonedHeaders["content-type"] = "application/json";

        try
        {
            Write-Host "Posting custom metric to Azure"
            Write-Host

            if ($logRequestUris) { Write-Host $request; }
            if ($logHeaders) { WriteHeaders $clonedHeaders; }
            if ($logContent) { Write-Host -ForegroundColor Gray $metricsBody; }

            $response = Invoke-WebRequest $uri -Method POST -Headers $clonedHeaders -Body $metricsBody;

            Write-Host
            Write-Host "Done >>>>> "(Get-Date).tostring()
            Write-Host
            $response;
        }
        catch
        {
            Write-Host -ForegroundColor Red $request;
            Write-Host -ForegroundColor Red $_.Exception.Message;
            throw;
        }
    }
    else
    {
        return $null
    }

}

####################################################

function Get-MetricsBody($eventID){

    <#
    .SYNOPSIS
    This function will generate a JSON with information required to create a custom metric on Azure Monitor
    .DEION
    Generates a JSON with information required to create a custom metric on Azure Monitor
    .EXAMPLE
    Get-MetricsBody()
    #>

    # Coment
    $result = Run-Test

    # Get Current Date - Format YYYY-MM-DDTHH:MM:SS
    $getDate = Get-Date -UFormat '+%Y-%m-%dT%H:%M:%S'

    Write-Host "Getting Body of Alert >>>>> "(Get-Date).tostring()
    Write-Host

    # Body of the Alert to be generated and/or updated
    # TODO - Add namespace to the Json dynamically
    $json = @"
    {
    "time": "$getDate",
    "data": {
        "baseData": {
            "metric": "$eventID",
            "namespace": "",
            "dimNames": [
              "Exists",
              "NotExists"
            ],
            "series": [
              {
                "dimValues": [
                  "FilesToProcess",
                  "Txt"
                ],
                "count": $result
              }
            ]
            }
            }
    }
"@

    Write-Host "Done >>>>> "(Get-Date).tostring()
    Write-Host
    $json;

}

####################################################