# https://sqlpal.blogspot.com/2023/08/protocols-enabled-in-sqlserver.html
<#
.SYNOPSIS
Returns SQL Server network protocol configuration from one or more remote Windows servers.

.DESCRIPTION
This script retrieves SQL Server network protocol information from one or more
remote Windows servers by reading the SQL Server registry keys under
SuperSocketNetLib.

You must provide at least one server name. You can provide a single server,
multiple servers, or import a list of servers from a text file.

The SQL Server instance name is optional. If omitted or set to $null, the
script returns protocol information for all SQL Server instances installed on
each target server.

The script returns PowerShell objects, which makes it easy to display results
on screen or export them. If the ImportExcel module is installed and the
Export-Excel command is available, results can be exported to Excel. If not,
the script automatically falls back to CSV export.

The script is intended for SQL Server running on Windows, where SQL Server
network protocol settings are stored in the Windows registry.

.PARAMETER server_name
One or more target server names. These may be short names, FQDNs, or names
loaded from a text file.

.PARAMETER instance_name
Optional SQL Server instance name.

Examples:
- Default instance:
  MSSQLSERVER

- Named instance:
  SQL2019DEV

If omitted or set to $null, all installed SQL Server instances are processed.

.PARAMETER export_to_csv
If $true, exports results to a CSV file.

.PARAMETER csv_file_path
Path to the CSV export file.

.PARAMETER export_to_excel
If $true, exports results to an Excel file when Export-Excel is available.
If Export-Excel is not available, the script exports to CSV instead.

.PARAMETER excel_file_path
Path to the Excel export file.

.INPUTS
System.String[]
You can provide one or more server names.

.OUTPUTS
System.Management.Automation.PSCustomObject

The script returns objects with these properties:
- target_server
- computer_name
- computer_fqdn
- sql_instance
- protocol_name
- property_name
- property_value

.NOTES
Blog post:
https://sqlpal.blogspot.com/2023/08/protocols-enabled-in-sqlserver.html

ImportExcel module:
https://github.com/dfinke/ImportExcel

Requirements:
- PowerShell remoting must be enabled on target servers.
- The account running the script must have permission to query the remote registry path.
- This script applies to SQL Server on Windows.

.LINK
https://sqlpal.blogspot.com/2023/08/protocols-enabled-in-sqlserver.html

.LINK
https://github.com/drupalgrupal/PowerShell/blob/main/Get%20List%20of%20Protocols%20Enabled%20in%20SQL%20Server.ps1


.EXAMPLE
[string[]]$server_name = @('SQLVM01')
[string]$instance_name = $null

Returns protocol information for all SQL Server instances on SQLVM01.

.EXAMPLE
[string[]]$server_name = @('SQLVM01','SQLVM02','SQLVM03')
[string]$instance_name = $null

Returns protocol information for all SQL Server instances on multiple servers.

.EXAMPLE
[string[]]$server_name = Get-Content -Path "$env:USERPROFILE\Documents\sql_servers.txt"
[string]$instance_name = $null

Returns protocol information for all SQL Server instances on servers listed in a text file.

.EXAMPLE
[string[]]$server_name = @('SQLVM01')
[string]$instance_name = 'MSSQLSERVER'

Returns protocol information only for the default instance on SQLVM01.
#>

# =========================
# HELP / CONFIGURATION
# =========================
#
# REQUIRED VARIABLES
#
# 1. $server_name
#    One or more server names.
#
#    Examples:
#    [string[]]$server_name = @('SQLVM01')
#    [string[]]$server_name = @('SQLVM01','SQLVM02','SQLVM03')
#    [string[]]$server_name = Get-Content -Path "$env:USERPROFILE\Documents\sql_servers.txt"
#
# 2. $instance_name
#    Optional SQL Server instance name.
#
#    Example:
#    [string]$instance_name = 'MSSQLSERVER'
#
#    Use $null to retrieve all SQL Server instances.
#
# EXPORT OPTIONS
#
# 3. $export_to_csv
#    If $true, exports results to CSV.
#
# 4. $csv_file_path
#    CSV output path.
#
# 5. $export_to_excel
#    If $true, attempts Excel export using Export-Excel.
#    If Export-Excel is unavailable, results are exported to CSV instead.
#
# 6. $excel_file_path
#    Excel output path.
#
# NOTES
#
# - If multiple servers are specified, $instance_name must be $null or empty.
# - If DNS resolution of a short server name fails, the original server name is used.
# - The script reads SQL Server protocol data from the Windows registry.
#

# Required variables
[string[]]$server_name    = @('AZWVPINF003D')
[string]$instance_name    = $null   # e.g. 'MSSQLSERVER'

# Export options
[bool]$export_to_csv      = $false
[string]$csv_file_path    = "$env:USERPROFILE\Documents\sql_server_enabled_protocols.csv"

[bool]$export_to_excel    = $true
[string]$excel_file_path  = "$env:USERPROFILE\Documents\sql_server_enabled_protocols.xlsx"


function Get-Sql-Protocols {
    [CmdletBinding()]
    param (
        [string]$instance_name,
        [string]$target_server
    )

    $computer_name      = $env:COMPUTERNAME
    $sql_registry_root  = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
    $instance_names_key = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL'

    try {
        $computer_fqdn = [System.Net.Dns]::GetHostEntry($computer_name).HostName
    }
    catch {
        $computer_fqdn = $computer_name
    }

    if (-not (Test-Path $instance_names_key)) {
        Write-Warning "Warning: No SQL Server instances found in registry on server '$computer_name'."
        return @()
    }

    $installed_sql_instances = (Get-Item $instance_names_key).GetValueNames()

    if ($instance_name -notin ('', $null)) {
        $instance_name = $instance_name.ToUpper()
        if ($installed_sql_instances.Contains($instance_name)) {
            $installed_sql_instances = $instance_name
        }
        else {
            throw "Error: SQL instance name '$instance_name' is invalid on server '$computer_name'."
        }
    }

    $result = @()

    foreach ($installed_sql_instance in $installed_sql_instances) {

        if ($installed_sql_instance -eq 'MSSQLSERVER') {
            $sql_instance_registry_path = 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\MSSQLServer'
        }
        else {
            $sql_instance_registry_path = Join-Path -Path $sql_registry_root `
                                                   -ChildPath "$installed_sql_instance\MSSQLServer"
        }

        $sql_instance_SuperSocketNetLib_path = "$sql_instance_registry_path\SuperSocketNetLib"

        if (-not (Test-Path $sql_instance_SuperSocketNetLib_path)) {
            Write-Warning "Warning: SuperSocketNetLib key not found for instance '$installed_sql_instance' on '$computer_name'."
            continue
        }

        $protocols = Get-ChildItem $sql_instance_SuperSocketNetLib_path

        foreach ($protocol in $protocols) {
            foreach ($protocolp in $protocol.GetValueNames()) {
                $result += [PSCustomObject]@{
                    target_server   = $target_server
                    computer_name   = $computer_name
                    computer_fqdn   = $computer_fqdn
                    sql_instance    = $installed_sql_instance
                    protocol_name   = $protocol.PSChildName
                    property_name   = $protocolp
                    property_value  = $protocol.GetValue($protocolp)
                }
            }
        }
    }

    return $result
}


if ($server_name.Count -gt 1 -and $instance_name -notin ('', $null)) {
    throw 'Error: A named instance in $instance_name is not compatible with multiple values in $server_name.'
}

$sql_protocols = @()

foreach ($server in $server_name) {

    try {
        $server_fqdn = [System.Net.Dns]::GetHostEntry($server).HostName
    }
    catch {
        $server_fqdn = $server
    }

    try {
        $sql_protocols += Invoke-Command -ComputerName $server_fqdn `
                                         -ScriptBlock ${function:Get-Sql-Protocols} `
                                         -ArgumentList $instance_name, $server_fqdn `
                                         -ErrorAction Stop
    }
    catch {
        Write-Warning "Warning: Failed to query server '$server_fqdn'. $($_.Exception.Message)"
    }
}

# Display on screen
$sql_protocols |
    Format-Table computer_name, computer_fqdn, sql_instance, protocol_name, property_name, property_value

# Export to CSV file
if ($export_to_csv) {
    Write-Information 'Exporting to CSV file...'
    $sql_protocols |
        Select-Object PSComputerName, computer_name, computer_fqdn, sql_instance, protocol_name, property_name, property_value |
        Export-Csv -Path $csv_file_path -Force -NoTypeInformation
}

# Export to Excel file
if ($export_to_excel) {

    if (Get-Command -Name Export-Excel -ErrorAction SilentlyContinue) {
        Write-Information 'Exporting to Excel file...'
        $sql_protocols |
            Select-Object PSComputerName, computer_name, computer_fqdn, sql_instance, protocol_name, property_name, property_value |
            Export-Excel -Path $excel_file_path `
                         -WorksheetName 'SQLProtocols' `
                         -TableName 'SQLProtocols' `
                         -TableStyle 'Light9' `
                         -AutoSize `
                         -NoNumberConversion '*'
    }
    else {
        Write-Warning 'Warning: Function Export-Excel not found. Falling back to CSV export...'
        $sql_protocols |
            Select-Object PSComputerName, computer_name, computer_fqdn, sql_instance, protocol_name, property_name, property_value |
            Export-Csv -Path $csv_file_path -Force -NoTypeInformation
    }
}

