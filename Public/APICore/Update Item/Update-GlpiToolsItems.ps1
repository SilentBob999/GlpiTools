<#
.SYNOPSIS
    Function Update an object (or multiple objects) existing in GLPI.
.DESCRIPTION
    Function Update an object (or multiple objects) into GLPI. You can choose between every items in Asset Tab.\
.PARAMETER UpdateTo
    Parameter specify where you want to update object. You can add your custom parameter options to Parameters.json file located in Private folder
.PARAMETER JsonPayload
    Parameter specify a JsonPayload with id of item to be updated, and others fields. You can get values to use, when you run Get-GlpiToolsComputer function.
.PARAMETER ItemId
    Parameter specify item id. You can find id in GLPI or, when you run Get-GlpiToolsComputer function.
.PARAMETER ItemsHashtableWithoutId
    Parameter specify a hashtable without id of item to be updated, and others fields.
    You provide id in -ItemId parameter.
    You can get values to use, when you run Get-GlpiToolsComputer function.
.EXAMPLE
    PS C:\> $example = "@
    {
	"input" : [
		{
			"id" : "15",
			"comment" : "updated from script 4"
		},
		{
			"id" : "17",
			"comment" : "updated from script 2"
		}
	]
}
@"
    PS C:\> Update-GlpiToolsItems -UpdateTo Computer -JsonPayload $example
    Example will Update item which id is 15 and 17 into Computers
.EXAMPLE
    PS C:\> $example =  @{name = "test"}
    PS C:\> Update-GlpiToolsItems -UpdateTo Computer -ItemId 5 -ItemsHashtableWithoutId $example
    Example will Update item which id is 5 into Computers
.INPUTS
    JsonPayload, or hashtable.
.OUTPUTS
    Information with id and message, which items were Updated.
.NOTES
    PSP 04/2019
#>

function Update-GlpiToolsItems {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [alias('UT')]
        [string]$UpdateTo,

        [parameter(Mandatory = $true,
            ParameterSetName = "ID")]
        [alias('IId')]
        [int]$ItemId,

        [parameter(Mandatory = $true,
            ParameterSetName = "ID")]
        [ValidateScript({ if ($_.ContainsKey('id')) {
                Throw "The HashTable contains id's of item. You have to provide id to -ItemId parameter, and provide here a hashtable without that id"
            } else {
                $true
            }
        })]
        [alias('IHWID')]
        [hashtable]$ItemsHashtableWithoutId,

        [parameter(Mandatory = $true,
            ParameterSetName = "JsonPayload")]
        [alias('JsPa')]
        [array]$JsonPayload,

        [parameter(Mandatory = $false,
            ParameterSetName = "JsonPayload")]
        [int]$MaxPayLoadSize = 100000
    )

    begin {
        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Set-GlpiToolsInitSession | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys
    }

    process {
        switch ($ChoosenParam) {
            JsonPayload {
                $bodyArray = [System.Collections.Generic.List[object]]::new()
                $UpdateResult = [System.Collections.Generic.List[object]]::new()
                $PayLoadBytes = ([System.Text.Encoding]::UTF8.GetBytes($JsonPayload))
                if ( $PayLoadBytes.Length -ge $MaxPayLoadSize ) {
                    $data = ($JsonPayload | ConvertFrom-Json).input
                    $max = $($data.count *  $MaxPayLoadSize / $PayLoadBytes.Length)
                    $Divider = [math]::ceiling($data.count / $max)
                    $max2 = [math]::ceiling($data.count / $Divider)
                    for ($i=0;$i -lt $(@($data).Count); $i+=($max2 + 1)){
                        $end = [System.Math]::min($i+$max2,@($data).Count)
                        $bodyArray.Add( ([System.Text.Encoding]::UTF8.GetBytes( $( @{input = $JsonPayload[$i..$end] }  |  ConvertTo-Json -Compress ) )) )
                    }
                } else {
                    $bodyArray.Add($PayLoadBytes)
                }
                foreach ($body in $bodyArray) {
                    try {
                        $params = @{
                            headers = @{
                                'Content-Type'  = 'application/json'
                                'App-Token'     = $AppToken
                                'Session-Token' = $SessionToken
                            }
                            method  = 'put'
                            uri     = "$($PathToGlpi)/$($UpdateTo)/"
                            body    = $body
                        }
                        Invoke-RestMethod @params | ForEach-Object { $UpdateResult.Add($_) }
                    }
                    catch {
                        $errors = $_
                        if ( $errors.Exception.Message -like "*The underlying connection was closed*" ) {
                            $CustomMessage = "Connection failure detected, consider using a smaller MaxPayLoadSize`n$errors.Exception.Message"
                            $CustomError = New-Object Management.Automation.ErrorRecord (
                                [System.Exception]::new($CustomMessage ,$errors.Exception.InnerException),$errors.FullyQualifiedErrorId,$errors.CategoryInfo.Category,$errors)
                            $PScmdlet.ThrowTerminatingError($CustomError)
                        } else {
                            throw $PSItem
                        }
                    }
                }
            }
            ItemId {
                $GlpiUpload = $ItemsHashtableWithoutId | ConvertTo-Json

                $Upload = '{ "input" : ' + $GlpiUpload + '}'

                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'put'
                    uri     = "$($PathToGlpi)/$($UpdateTo)/$($ItemId)"
                    body    = ([System.Text.Encoding]::UTF8.GetBytes($Upload))
                }
                $UpdateResult = Invoke-RestMethod @params
            }
            Default { Write-Verbose "You didn't specified any parameter, choose from one available" }
        }

        foreach ($R in @($UpdateResult)){
            if ($R -is [string]) {
                foreach ($id in @(($JsonPayload | ConvertFrom-Json).input.where({
                    $_.id -notin @(
                        $UpdateResult[1].ForEach({$_.PSObject.Properties.Where({$_.TypeNameOfValue -EQ "System.Boolean"}).name})
                        )
                    }).id) ){
                        [pscustomobject]@{
                            id = $id
                            success = $false
                            message = $R
                        }
                    }
            }
            if ($R.message.count -ge 1) {
                foreach ($R2 in @($R)){
                     [pscustomobject]@{
                            id = $(($R2.PSObject.Properties.Where({$_.TypeNameOfValue -EQ "System.Boolean"})).name)
                            success = $(($R2.PSObject.Properties.Where({$_.TypeNameOfValue -EQ "System.Boolean"})).value)
                            message = $(($R2.PSObject.Properties.Where({$_.name -EQ "message"})).value)
                    }
                }
            }
        }

    }

    end {
        Set-GlpiToolsKillSession -SessionToken $SessionToken
    }
}

$UpdateToValidate = {
    param ($commandName, $parameterName, $stringMatch, $fakeBoundParameter)
    $ModulePath = Split-Path (Get-Module -Name GlpiTools).Path -Parent
    (Get-Content "$($ModulePath)\Private\Parameters.json" | ConvertFrom-Json).GlpiComponents | Where-Object {$_ -match "$stringMatch"}
}
Register-ArgumentCompleter -CommandName Update-GlpiToolsItems -ParameterName UpdateTo -ScriptBlock $UpdateToValidate