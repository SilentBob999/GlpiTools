<#
.SYNOPSIS
    Function which convert parameters of specified GLPI component.
.DESCRIPTION
    Function which convert parameters of specified GLPI component.
.EXAMPLE
    PS C:\> Get-GlpiToolsParameters -Parameter users_id -Value 3
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    PSP 07/2019
#>

function Get-GlpiToolsParameters {
    [CmdletBinding()]
    param (

        [parameter(Mandatory = $true,
            ParameterSetName = "Parameter")]
        $Parameter,
        [parameter(Mandatory = $true,
            ParameterSetName = "Parameter")]
        [AllowEmptyString()]
        [AllowNull()]
        $Value

    )

    begin {
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
        $SessionToken = $Script:SessionToken

        $AppToken = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty PathToGlpi
        $SessionToken = Set-GlpiToolsInitSession -Verbose:$false | Select-Object -ExpandProperty SessionToken
    }

    process {

        try {
            if  ($Parameter -eq "entities_id") {
                $ConvertedValue = $Value | Get-GlpiToolsEntities | Select-Object -ExpandProperty CompleteName -ErrorAction Stop
            } elseif ($Parameter -eq "users_id_tech" ) {
                $ConvertedValue = $Value | Get-GlpiToolsUsers -Raw | Select-Object realname, firstname | ForEach-Object { "{0} {1}" -f $_.firstname,$_.realname } -ErrorAction Stop
            } elseif ($Parameter -eq "groups_id_tech" ) {
                $ConvertedValue = $Value | Get-GlpiToolsGroups -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "autoupdatesystems_id"  ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsOSUpdateSources | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ( $Parameter -eq "locations_id"  ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsLocations -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "domains_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsDomains -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "networks_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsNetworks -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameters -eq "computermodels_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsComputerModels -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameters -eq "computertypes_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsComputerTypes -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "manufacturers_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsManufacturers -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "users_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsUsers -Raw | Select-Object realname, firstname | ForEach-Object { "{0} {1}" -f $_.firstname,$_.realname } -ErrorAction Stop
            } elseif ($Parameter -eq "groups_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsGroups -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "states_id" ) {
                $ConvertedValue = $Value | Get-GlpiToolsDropdownsStatusesOfItems -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "softwares_id") {
                $ConvertedValue = $Value | Get-GlpiToolsSoftware -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "softwareversions_id") {
                $ConvertedValue = $Value | Get-GlpiToolsSoftwareVersions -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            } elseif ($Parameter -eq "computers_id") {
                $ConvertedValue = $Value | Get-GlpiToolsComputers -Raw | Select-Object -ExpandProperty name -ErrorAction Stop
            }
            else {
                $ConvertedValue = $Value
            }
        } catch {
            $ConvertedValue = 0
        }


    }

    end {
        $ConvertedValue
        Set-GlpiToolsKillSession -SessionToken $SessionToken -Verbose:$false
    }
}