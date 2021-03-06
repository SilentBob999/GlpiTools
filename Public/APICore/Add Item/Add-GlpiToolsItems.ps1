<#
.SYNOPSIS
    Function Add an object (or multiple objects) into GLPI.
.DESCRIPTION
    Function Add an object (or multiple objects) into GLPI. You can choose between every items in Asset Tab.
.PARAMETER AddTo
    Parameter specify where you want to add new object.
    You can add your custom parameter options to Parameters.json file located in Private folder
.PARAMETER HashtableToAdd
    Parameter specify a hashtable with fields of itemtype to be inserted.
.PARAMETER JsonPayload
    Parameter specify a hashtable with "input" parameter to be a JsonPayload.
.EXAMPLE
    PS C:\> Add-GlpiToolsItems -AddTo Computer -HashtableToAdd @{name = "test"} | ConvertTo-Json
    Example will add item into Computers
.EXAMPLE
    PS C:\> $example =  @{name = "test"} | ConvertTo-Json
    PS C:\> Add-GlpiToolsItems -AddTo Computer -HashtableToAdd $example
    Example will add item into Computers
.EXAMPLE
    PS C:\> $example = @{ name = "test" } | ConvertTo-Json
    PS C:\> $upload = '{ "input" : ' + $example + '}'
    PS C:\> Add-GlpiToolsItems -AddTo Computer -JsonPayload $upload
.EXAMPLE
    PS C:\> $example = "@
    {
	"input" : [
		{
			"name" : "test1",
			"comment" : "updated from script"
		},
		{
			"name" : "test2",
			"comment" : "updated from script"
		}
	]
}
@"
    PS C:\> Add-GlpiToolsItems -AddTo Computer -JsonPayload $example
    Example will Add items into Computers
.INPUTS
    Hashtable with "input" parameter, or JsonPayload    .
.OUTPUTS
    Information with id and message, which items were added.
.NOTES
    PSP 04/2019
#>

function Add-GlpiToolsItems {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [alias('AT')]
        [string]$AddTo,

        [parameter(Mandatory = $true,
            ParameterSetName = "HashtableToAdd")]
        [alias('HashToAdd')]
        [hashtable]$HashtableToAdd,

        [parameter(Mandatory = $false,
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
        $AddResult = [System.Collections.Generic.List[object]]::new()

        switch ($ChoosenParam) {
            HashtableToAdd {
                $GlpiUpload = $HashtableToAdd | ConvertTo-Json

                $Upload = '{ "input" : ' + $GlpiUpload + '}'

                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'post'
                    uri     = "$($PathToGlpi)/$($AddTo)/"
                    body    = ([System.Text.Encoding]::UTF8.GetBytes($Upload))
                }
                Invoke-RestMethod @params  | ForEach-Object { $AddResult.Add($_) }
            }
            JsonPayload {
                $bodyArray = [System.Collections.Generic.List[object]]::new()
                $PayLoadBytes = ([System.Text.Encoding]::UTF8.GetBytes($JsonPayload))
                if ( $PayLoadBytes.Length -gt $MaxPayLoadSize ) {
                    #Write-Verbose "Load exceed the maximum load of $MaxPayLoadSize and will be split. Load size $($PayLoadBytes.Length)"
                    $data = ($JsonPayload | ConvertFrom-Json).input
                    $max = $(@($data).count *  $MaxPayLoadSize / $PayLoadBytes.Length)
                    $Divider = $(@($data).count / $max)
                    $max2 = $(@($data).count / $Divider)
                    if ($max2 -isnot [int]) {
                        $max2 = [math]::ceiling( [double]$max2 )
                    }
                    for ($i=0;$i -lt $(@($data).Count); $i+=($max2 + 1)){
                        $end = [System.Math]::min($($i+$max2),@($data).Count)
                        $SplitPayLoad = ([System.Text.Encoding]::UTF8.GetBytes( $( @{input = $data[$i..$end] }  |  ConvertTo-Json -Compress ) ))
                        $bodyArray.Add( $SplitPayLoad )
                        Write-Verbose "Split element $i .. $end, payload size  $($SplitPayLoad.Length)"
                    }
                } else {
                    $bodyArray.Add($PayLoadBytes)
                }
                foreach ($body in $bodyArray) {
                    #Write-Verbose "bodyArray count : $($bodyArray.count), bodyArray Length : $($bodyArray.Length), body Length : $($body.Length)"
                    try {
                        $params = @{
                            headers = @{
                                'Content-Type'  = 'application/json'
                                'App-Token'     = $AppToken
                                'Session-Token' = $SessionToken
                            }
                            method  = 'post'
                            uri     = "$($PathToGlpi)/$($AddTo)/"
                            body    = $body
                        }
                        Write-Verbose "RestMethod : Addto $AddTo, body length : $($body.Length)"
                        Invoke-RestMethod @params | ForEach-Object { $AddResult.Add($_) }
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
            Default { Write-Verbose "You didn't specified any parameter, choose from one available" }
        }
        # OUTPUT
        foreach ($R in @($AddResult)){
            if ($R.message.count -ge 1) {
                foreach ($R2 in @($R)){
                    if ($R2 -isnot [string]) { # Never output the occasional "first string" {ERROR_GLPI_PARTIAL_RESULT}
                        $R2
                    }
                }
            } else {
                $R # this is probably useless
            }
        }

    }

    end {
        Set-GlpiToolsKillSession -SessionToken $SessionToken
    }
}

$AddToValidate = {
    param ($commandName, $parameterName, $stringMatch)
    $ModulePath = Split-Path (Get-Module -Name GlpiTools).Path -Parent
    (Get-Content "$($ModulePath)\Private\Parameters.json" | ConvertFrom-Json).GlpiComponents | Where-Object {$_ -match "$stringMatch"}
}
Register-ArgumentCompleter -CommandName Add-GlpiToolsItems -ParameterName AddTo -ScriptBlock $AddToValidate