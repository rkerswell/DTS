<#
 .SYNOPSIS
    Creates environments in orchestrator

 .DESCRIPTION
    Creates environments in the given orchestrator based on data in Environments.json

 .PARAMETER orchuserName
    Orchestrator username.

 .PARAMETER orchPassword
    Orchestrator password

 .PARAMETER orchestratorURL
    Orchestrator URL where tenant needs to be created.

 .PARAMETER tenantName
    Tenant in which assets to be created
#>

param(
[Parameter(Mandatory = $true)]
 [string] 
 $path ,

 [Parameter(Mandatory = $true)]
 [string]
 $orchuserName ,

 [Parameter(Mandatory = $true)]
 [string]
 $orchPassword ,

 [Parameter(Mandatory = $true)]
 [string]
 $orchestratorURL ,

 [Parameter(Mandatory = $true)]
 [string]
 $tenantName  
)

<#
.SYNOPSIS
    install uipath powershell module
#>
Function InstallUipath{
    # install nuget 
     Install-PackageProvider -Name NuGet -Force

    Import-Module PowerShellGet

    # register uipath repository
    Register-PSRepository -Name UiPath -SourceLocation https://www.myget.org/F/uipath-dev/api/v2 

    # install uipath powershell module
    $uipathmodule = Get-Module -Name "UiPath.Powershell"

    if(!$uipathmodule) {
        Install-Module -Repository UiPath -Name UiPath.Powershell -Force
        Import-Module UiPath.PowerShell
    }
}

<#
.SYNOPSIS
    Uploads library in orchestrator
#>
Function UploadLibrary{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $packagePath,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

    Add-UiPathLibrary -LibraryPackage $packagePath -AuthToken $authToken
}

<#
.SYNOPSIS
    Creates environment in orchestrator
#>
Function CreateEnvironment{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $envName,
    [string] $description = '',
    [string[]] $robotNames,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

    $env = Get-UiPathEnvironment -Name $envName -AuthToken $authToken

    if(! $env){
      # create environment
      $env = Add-UiPathEnvironment -Name $envName -Description $description -AuthToken $authToken 
    }else {
       # throw "Environment with name $envName already exists. Please try again with different name."
    }

    foreach($robotname in $robotNames){
        $robot = Get-UiPathRobot -Name $robotname -AuthToken $authToken      
        if($robot){    
            $envrobots = Get-UiPathEnvironmentRobot -Environment $env -AuthToken $authToken
            if(! $envrobots.Contains($robot)){
                # attach robot to environment
                Add-UiPathEnvironmentRobot -Environment $env -Robot $robot -AuthToken $authToken
            }      
        }
    }
}


<#
.SYNOPSIS
    Creates process in orchestrator
#>
Function CreateProcess{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $name,
    [string] $description = '',
    [Parameter(Mandatory = $true)]
    [string] $envName,
    [Parameter(Mandatory = $true)]
    [object] $package,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

    #$env = Get-UiPathEnvironment -Name $envName -AuthToken $authToken

    #If($env){
        if($package.version -eq ""){
            $pkg = Get-UiPathPackageVersion -Id $package.name  -AuthToken $authToken
        }else {
            $pkg = Get-UiPathPackageVersion -Id $package.name -Version $package.version -AuthToken $authToken
        }


        if($pkg){
            $process = Get-UiPathProcess -Name $name -AuthToken $authToken
            if(! $process){
                #Add-UiPathProcess -Name $name -Environment $env -PackageId $pkg[0].Id -AuthToken $authToken -PackageVersion $pkg[0].Version
                Add-UiPathProcess -Name $name -PackageId $pkg[0].Id -AuthToken $authToken -PackageVersion $pkg[0].Version
            }else {
                Update-UiPathProcess -Process $process -AuthToken $authToken -Latest
            }           
        }
    #}   
}

<#
.SYNOPSIS
    Creates assets of type text in orchestrator
#>
Function CreateAsset-Text{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $assetName,
    [Parameter(Mandatory = $true)]
    [string] $textvalue,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

$asset = Get-UiPathAsset -Name $assetName -ExactMatch -AuthToken $authToken

if(! $asset){
    # create asset
    Add-UiPathAsset -Name $assetName -TextValue $textvalue -AuthToken $authToken 
}<# else {
    # edit asset
    Edit-UiPathAsset -Asset $asset -TextValue $textvalue -AuthToken $authToken
} #>

}

<#
.SYNOPSIS
    Creates assets of type int in orchestrator
#>
Function CreateAsset-Int{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $assetName,
    [Parameter(Mandatory = $true)]
    [int] $intvalue,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

$asset = Get-UiPathAsset -Name $assetName -ExactMatch  -AuthToken $authToken

if(! $asset){
    # create asset
    Add-UiPathAsset -Name $assetName -IntValue $intvalue -AuthToken $authToken
}<# else {
    # edit asset
    Edit-UiPathAsset -Asset $asset -IntValue $intvalue -AuthToken $authToken
}#>

}

<#
.SYNOPSIS
    Creates assets of type bool in orchestrator
#>
Function CreateAsset-Bool{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $assetName,
    [Parameter(Mandatory = $true)]
    [boolean] $boolvalue,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

    $asset = Get-UiPathAsset -Name $assetName -ExactMatch  -AuthToken $authToken

    if(! $asset){
        # create asset
        Add-UiPathAsset -Name $assetName -BoolValue $boolvalue -AuthToken $authToken
    }<# else {
        # edit asset
        Edit-UiPathAsset -Asset $asset -BoolValue $boolvalue -AuthToken $authToken
    } #>
}

<#
.SYNOPSIS
    Creates assets of type credential in orchestrator
#>
Function CreateAsset-Credential{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $assetName,
    [Parameter(Mandatory = $true)]
    [string] $userName,
    [Parameter(Mandatory = $true)]
    [string] $passwordText,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

    $asset = Get-UiPathAsset -Name $assetName -ExactMatch  -AuthToken $authToken

    # create password object
    $password = ConvertTo-SecureString $passwordText -AsPlainText -Force
    $PSCredetialObj = New-Object System.Management.Automation.PSCredential ($userName, $password)

    if(! $asset){
        # create asset
        Add-UiPathAsset -Name $assetName -Credential $PSCredetialObj -AuthToken $authToken
    }<# else {
        # edit asset
        Edit-UiPathAsset -Asset $asset -Credential $PSCredetialObj -AuthToken $authToken
    } #>
}

<#
.SYNOPSIS
    Creates Folder in logged in orchestrator tenant
#>
Function CreateFolder{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $FolderPath,
    [Parameter(Mandatory = $true)]
    [string] $PermissionModel,
    [Parameter(Mandatory = $true)]
    [string] $ProvisionType,
    [string] $Description = '',
    [int] $ParentId,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)
    
    $folder = Get-UiPathFolder -FullyQualifiedName $FolderPath -AuthToken $authToken

    if(! $folder){
      # create folder
      Add-UiPathFolder -DisplayName $FolderPath -PermissionModel $PermissionModel -ProvisionType $ProvisionType -Description $Description -AuthToken $authToken 
    }
}

<#
.SYNOPSIS
    Creates queue in orchestrator
#>
Function CreateQueue{
    Param( 
    [Parameter(Mandatory = $true)]
    [string] $queueName,
    [string] $description = '',
    [Parameter(Mandatory = $true)]
    [bool] $uniqueReference,
    [Parameter(Mandatory = $true)]
    [bool] $autoRetry,
    [Parameter(Mandatory = $true)]
    [int] $maxRetry,
    [Parameter(Mandatory = $true)]
    [UiPath.PowerShell.Models.AuthToken] $authToken)

$queue = Get-UiPathQueueDefinition -Name $queueName -AuthToken $authToken

if(! $queue){
    # create queue
    if($uniqueReference -and $autoRetry){
        Add-UiPathQueueDefinition -Name $queueName -Description $description -EnforceUniqueReference -AcceptAutomaticallyRetry -MaxNumberOfRetries $maxRetry -AuthToken $authToken
    }
    elseif($uniqueReference -and ! $autoRetry){
        Add-UiPathQueueDefinition -Name $queueName -Description $description -EnforceUniqueReference -AuthToken $authToken
    }
    elseif(! $uniqueReference -and $autoRetry){
        Add-UiPathQueueDefinition -Name $queueName -Description $description -AcceptAutomaticallyRetry -MaxNumberOfRetries $maxRetry -AuthToken $authToken
    }
    elseif(! $uniqueReference -and ! $autoRetry){
        Add-UiPathQueueDefinition -Name $queueName -Description $description -AuthToken $authToken
    }
}else {
    # throw "Queue with name $queueName already exists. Please try again with different name."
}

}


#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# install uipath powershell package
InstallUipath

$authToken = Get-UiPathAuthToken -URL $orchestratorURL -Password $orchPassword -Username $orchuserName  -TenantName $tenantName

# Read resources from the json file that are to be created
$json = (Get-Content -Path $path -Raw) | ConvertFrom-Json


# Create environments
foreach($environment in $json.environments){
    CreateEnvironment -envName $environment.name -description $environment.description -robotNames $environment.robots -authToken $authToken
}


foreach($folder in $json.folders){

    # Create folder if it does not exist
    CreateFolder -FolderPath $folder.name -PermissionModel "FineGrained" -ProvisionType "Automatic" -authToken $authToken  

    # Set Folder
    Set-UiPathCurrentFolder -FolderPath $folder.name -AuthToken $authToken
    
    # Create process
    foreach($process in $json.processes){
        CreateProcess -name $process.name -description $process.description -envName $process.environmentName -package $process.package -authToken $authToken
    }

    # Create assets
    # iterate over each object in json file
    foreach($assetType in $json.assets) {
        switch($assetType.type){
            "Text" {
                foreach($textasset in $assetType.values){
                    CreateAsset-Text -assetName $textasset.name -textvalue $textasset.value -authToken $authToken
                }
                break
            }
            "Int" {
                foreach($intasset in $assetType.values){
                    CreateAsset-Int -assetName $intasset.name -intvalue $intasset.value -authToken $authToken
                }
                break
            }        
            "Bool" {
                foreach($boolasset in $assetType.values){
                    CreateAsset-Bool -assetName $boolasset.name -boolvalue $boolasset.value -authToken $authToken
                }
                break
            }       
            "Credential" {
                foreach($credasset in $assetType.values){
                    CreateAsset-Credential -assetName $credasset.name -userName $credasset.username -passwordText $credasset.password -authToken $authToken
                }
                break
            }
        }
    }

    # Create queues
    foreach($queue in $json.queues){
        createQueue -queueName $queue.name -description $queue.description -uniqueReference $queue.uniqueReference -autoRetry $queue.autoRetry -maxRetry $queue.maxRetry -authToken $authToken       
    }
}


