<#
Blog post: https://sqlpal.blogspot.com/2023/08/protocols-enabled-in-sqlserver.html

DISCRIPTION:

The script will return the enabled protocols in a SQL instance on a 
remote server and their pertinent properties. You do have to give it 
a server name. You can even provide multiple servers or even a text 
file with list of all your servers. The SQL instance is an optional 
variable, in which case the script will return protocol information 
on all sql instances installed in the given server/s. A nice thing 
about this script is that it returns this information as a PowerShell 
object, an array object, to be specific. That makes it easier not 
only to display results on the screen, it also allows you to pipe 
the results to a Comma  Separated Values file (CSV) or even Microsoft 
Excel if the required module, ImportExcel,  for it is available on 
the computer where you are running this script from. You can install 
the module from https://github.com/dfinke/ImportExcel.  I decided to 
only display a warning if the module is not available, 
rather than throwing an ugly error.

VARIABLES:

1.   $server_name
     A value for this variable is required
     There are 3 ways you can assing it a value
     
     a.  A single server name
         $server_name = 'MySQLServer'
     
     b.  Multiple server names as an array
         $server_name = @('MySQLServer', 'MySQLServer2', 'MySQLServer3')

     c.  Import server names from a plain text file
         $server_name = Get-Content -Path "$env:USERPROFILE\Documents\sql_servers.csv"         


2.   $instance_name
     Name of the SQL Server instance. For the default sql instance, 
     the value should be MSSQLSERVER, for example: $instance_name  = 'MSSQLSERVER'

     If $instance_name is omitted or set to $null, the script will return protocols
     information for all installed sql instances

     You cannot specify $instance_name if the $server_name contains multiple servers.
     This limitation can be overcome, like some others, but I decided not to at this point.


3.   $export_to_csv
     This is a $true/$false value. If $true then the script will export the results to 
     a CSV file.

4.   $csv_file_path
     Path and name of the CSV file. 
     Default value is "$env:USERPROFILE\Documents\sql_server_enabled_protocols.csv"


5.   $export_to_excel
     This is a $true/$false value. If $true then the script will export the results to
     an Excel file only if the Export-Excel is available.   

6.   $excel_file_path
     Path and name of the Excel file. 
     Default value is "$env:USERPROFILE\Documents\sql_server_enabled_protocols.xlsx"


#>

# Required variables
[string]$server_name     = 'SQLMV01'
[string]$instance_name   = $null # 'MSSQLSERVER'

# Export options
[bool]$export_to_csv     = $false
[string]$csv_file_path   = "$env:USERPROFILE\Documents\sql_server_enabled_protocols.csv"

[bool]$export_to_excel   = $true
[string]$excel_file_path = "$env:USERPROFILE\Documents\sql_server_enabled_protocols.xlsx"


                  
Function Get-sql-protocols
{
    Param 
    (
        [string]$instance_name
 
    )

$computer_name = $env:COMPUTERNAME 
$sql_registry_root        = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
$installed_sql_instances = (Get-Item 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').GetValueNames()

if ($instance_name -notin ('', $null))
{
    # VALIDATE THE INSTANCE NAME
    
    $instance_name = $instance_name.ToUpper()
    if($installed_sql_instances.Contains($instance_name))
    {
        $installed_sql_instances = $instance_name
    }
    else
    {
        THROW "Error: SQL instance name $instance_name is invalid."
    }
}
   

$my_custom_object = @()

foreach($installed_sql_instance in $installed_sql_instances)
{
    if($installed_sql_instance -eq 'MSSQLSERVER')
    {
        $sql_instance_registry_path = 'HKLM:\SOFTWARE\Microsoft\MSSQLServer\MSSQLServer'
    }
    else 
    {
        $sql_instance_registry_path = Join-Path -Path $sql_registry_root `
                                       -ChildPath "$installed_sql_instance\MSSQLServer"
    }

    $sql_instance_SuperSocketNetLib_path = "$sql_instance_registry_path\SuperSocketNetLib"
    $protocols = Get-ChildItem $sql_instance_SuperSocketNetLib_path

    foreach ($protocol in $protocols)
    {
        foreach($protocolp in $protocol.GetValueNames())
        {
        
            $my_custom_object += [PSCustomObject]@{
                    computer_name    = $computer_name
                    sql_instance     = $installed_sql_instance
                    protocol_name    = $protocol.PSChildName
                    property_name    = $protocolp
                    property_value   = $protocol.GetValue($protocolp)
                }
        
        }
    }
    }

$my_custom_object
}

if($server_name.GetType().Name -ne 'String' -and $instance_name -notin ('', $null))
{
    THROW 'Error: A value of named instance in $instance_name is not compatible with an array for the $server_name'
}
else
{
    $sql_protocols = Invoke-Command -ComputerName $server_name   `
                                    -ScriptBlock ${Function:Get-sql-protocols} `
                                    -ArgumentList $instance_name

    $sql_protocols | Format-Table  computer_name, sql_instance, protocol_name, property_name, property_value
    # Export to a CSV file
    if ($export_to_csv)
    {
        Write-Information 'Exporting to CSV file....'
        $sql_protocols | Select-Object PSComputerName, sql_instance, protocol_name, property_name, property_value | 
                         Export-Csv -Path $csv_file_path -Force -NoTypeInformation
    }

    # Export to Excel file
    if ($export_to_excel)
    {
        
        if (Get-Command -Name Export-Excel -ErrorAction SilentlyContinue)
        {
            Write-Information  'Exporting to Excel file....'
            $sql_protocols | Select-Object PSComputerName, sql_instance, protocol_name, property_name, property_value | 
                             Export-Excel -Path $excel_file_path -WorksheetName "SQLProtocols" `
                             -TableName "SQLProtocols" -TableStyle Light9 -AutoSize -NoNumberConversion '*'
        }
        else
        {
            Write-Warning "Warning:Function Export-Excel not found. Skipping export to Excel..."
        }

    }


}
