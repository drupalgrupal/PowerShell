# https://sqlpal.blogspot.com/2023/09/How-To-Gain-Access-To-SQLServer-As-DBA.html

##### CAUTION: THE SCRIPT WILL STOP AND RESTART YOUR SQL SERVER INSTANCE!!!!!!!!! 
<#
THIS SCRIPT IS INTENDED TO GET ACCESS TO SQL SERVER ONLY IF 
YOU DON'T HAVE SYSADMIN PERMISSION. USE ONLY IN EMERGENCY.

#>

<#
.NOTATION
This script is intentionally lengthy for several important reasons:

- It must handle multiple complex steps safely to grant sysadmin access to SQL Server
- It needs to validate environment prerequisites such as elevated rights and service state
- The script carefully stops, starts, and manages dependencies of SQL Server services
- Confirmation prompts and detailed error handling are included to prevent unintended disruptions
- To avoid automation mistakes, explicit validations and user prompts are mandatory
- The overall complexity reflects the sensitive operation of forcibly gaining sysadmin access

Please read and understand each section of the script carefully before using it,
and always run this script in a controlled environment with proper permissions.

#>

<#
REQUIREMENTS:
1. Local Administrator rights on the server
2. Run locally or via Invoke-Command with PSRemoting enabled (default on Windows Server 2012+)
3. Elevated PowerShell session (Run as Administrator)

PARAMETERS:
- $login_to_be_granted_access (string, required): Windows or SQL login to grant sysadmin access
- $sql_instance_name (string, optional): SQL instance name (default instance if omitted)
- $confirm (bool, optional): Prompt for confirmation before stopping SQL service. Default: $true
- $sql_login_password (string, optional): SQL login password required if SQL login

#>

<# 
Examples:

Example 1: Running the Script Locally

- Save the script on your local device, for example as C:\Scripts\Gain-SqlSysadminAccess.ps1
- Open PowerShell with Administrative privileges (Run as Administrator).
- Navigate to the folder containing your script, for example: 
  cd C:\Scripts

- Run the script with required parameters. For example, to grant sysadmin access to a 
  Windows login named "DOMAIN\User1" on default instance with confirmation prompt:

.\Gain-SqlSysadminAccess.ps1 -login_to_be_granted_access "DOMAIN\User1" -confirm $false


Example 2: Running the Script Remotely Using Invoke-Command

- From your local machine with PowerShell launched as Administrator, 
  run the script on a remote computer (e.g., RemoteServer01). 
  Make sure PSRemoting is enabled on the remote server.

- Use the following command to invoke the script remotely:

# Run the local script on a remote computer, passing parameters
Invoke-Command -ComputerName RemoteServer01 `
    -FilePath "C:\Scripts\Gain-SqlSysadminAccess.ps1" `
    -ArgumentList "DOMAIN\User1", "SQL2022AG01", $false

- Replace parameters accordingly for your target environment


#>

param (
    [string] $login_to_be_granted_access = 'sqladmin',
    [string] $sql_instance_name = 'SQL2022AG01',
    [bool] $confirm = $true,
    [string] $sql_login_password = 'WA1!!1P7JRjN7F4eibEES&IxU%Elgw6b#'
)

# Set default preferences
$ErrorActionPreference = 'Stop'
$WarningPreference = 'Continue'
$InformationPreference = 'Continue'

# Assume default instance if sql_instance_name not specified
if (-not $sql_instance_name) { $sql_instance_name = 'MSSQLSERVER' }
if ($null -eq $confirm) { $confirm = $true }

Write-Information "Computer Name: $env:COMPUTERNAME"
Write-Information "SQL Instance Name: $sql_instance_name`n"

# Confirm prompt if required
if ($confirm) {
    $valid_responses = 'Yes', 'yes', 'No', 'no'
    do {
        Write-Warning "##### CAUTION: THE SCRIPT WILL STOP AND RESTART YOUR SQL SERVER INSTANCE!!!!!!!!!"
        $response = Read-Host "Are you sure you want to continue (Yes/No)?"
        if (-not $valid_responses.Contains($response)) {
            Write-Host "Please enter Yes or No"
        }
    } until ($valid_responses.Contains($response))

    if ($response -in @('No', 'no')) { return }
}
else {
    Write-Warning "Confirmation prompts are disabled."
    Write-Information ""
}

# Validate mandatory parameters
if (-not $sql_instance_name -or -not $login_to_be_granted_access) {
    throw "Error: Both `\$sql_instance_name` and `\$login_to_be_granted_access` are required."
}
if (-not $login_to_be_granted_access.Contains('\') -and -not $sql_login_password) {
    throw "A password must be provided for SQL Login."
}

# Check for elevated privileges
$isAdmin = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Owner -eq 'S-1-5-32-544'
if (-not $isAdmin) {
    throw "Error: Powershell must be launched in elevated privileges mode (Run as Administrator)."
}

# Determine service and SQL Server instance names
if ($sql_instance_name -eq 'MSSQLSERVER') {
    $service_name = 'MSSQLSERVER'
    $sql_server_instance = '.'
}
else {
    $service_name = "MSSQL`$$sql_instance_name"
    $sql_server_instance = ".\$sql_instance_name"
}

Write-Information "SQL Server Instance: $sql_server_instance"
Write-Information "Service Name: $service_name`n"

# Get SQL service and dependent services
$sql_service = Get-Service -Name $service_name -ErrorAction Stop
$dependent_services = $sql_service.DependentServices

if (-not $sql_service) {
    throw "Error: SQL instance '$sql_instance_name' or service '$service_name' not found."
}

Write-Information "Service Status: $($sql_service.Status)"
Write-Information "Service Startup Type: $($sql_service.StartType)`n"

# Re-enable if disabled
if ($sql_service.StartType -eq 'Disabled') {
    Write-Warning "SQL instance '$sql_instance_name' is currently disabled."

    if ($confirm) { Set-Service -Name $service_name -StartupType Manual -Confirm }
    else { Set-Service -Name $service_name -StartupType Manual }

    $sql_service.Refresh()
    if ($sql_service.StartType -eq 'Disabled') {
        throw "Error: Cannot continue while SQL instance is Disabled."
    }
}

# Stop the service if running
if ($sql_service.Status -eq 'Running') {
    Write-Warning "Stopping service: $service_name and its dependent services..."

    if ($confirm) { Stop-Service -InputObject $sql_service -Confirm -Force }
    else { Stop-Service -InputObject $sql_service -Force }

    Start-Sleep -Seconds 1

    $sql_service.Refresh()
    if ($sql_service.Status -ne 'Stopped') {
        throw "Error: SQL instance service '$service_name' did not stop as expected."
    }
}

# Start the service in single-user mode if appropriate
$sql_service.Refresh()
if ($sql_service.Status -ne 'Running' -and $sql_service.StartType -in @('Manual', 'Automatic')) {
    Write-Warning "Starting SQL Server service in single user mode..."
    Write-Information ""

    net start $service_name /f /m"SQLCMD" | Out-Null
    Start-Sleep -Seconds 1

    $sql_service.Refresh()
    if ($sql_service.Status -eq 'Running') {

        if ($login_to_be_granted_access.Contains('\')) {
            $sql = @"
CREATE LOGIN [$login_to_be_granted_access] FROM WINDOWS;
GO
ALTER SERVER ROLE sysadmin ADD MEMBER [$login_to_be_granted_access];
GO
SELECT @@ERROR AS [ErrMsg];
GO
"@
        }
        else {
            $sql = @"
CREATE LOGIN [$login_to_be_granted_access] WITH PASSWORD=N'$sql_login_password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER [$login_to_be_granted_access];
SELECT @@ERROR AS [ErrMsg];
"@
        }

        Write-Information "Adding login '$login_to_be_granted_access' to SYSADMIN role..."
        Write-Information $sql

        sqlcmd.exe -E -S $sql_server_instance -Q $sql

        Write-Information ""

        $check_permission = @"
IF EXISTS (
    SELECT * FROM sys.server_role_members
    WHERE member_principal_id = SUSER_ID('$login_to_be_granted_access')
      AND role_principal_id = SUSER_ID('sysadmin')
)
    PRINT '****** VERIFICATION SUCCEEDED ****************'
ELSE
    RAISERROR('ERROR: Verification failed.', 16, 1);
GO
"@

        Write-Information "Verifying sysadmin permissions..."
        Write-Information $check_permission

        sqlcmd.exe -E -S $sql_server_instance -Q $check_permission

        Write-Information ""
        Write-Information "Restarting SQL instance in normal mode..."

        net stop $service_name | Out-Null
        net start $service_name | Out-Null

        Write-Information ""
        Write-Information "Restart dependent services if they were running previously"
        Write-Information ""
        $dependent_services | Format-Table -Property DisplayName, Status, StartType
        Write-Information ""

        foreach ($dependent_service in $dependent_services) {

            $dependent_service_name = $dependent_service.Name
            if ($dependent_service.Status -eq 'Running') {
                if ((Get-Service -Name $dependent_service_name).Status -ne 'Running') {
                    Write-Information "Starting dependent service: $dependent_service_name"
                    $dependent_service.Start()
                }
            }
        }
    }
    else {
        throw "Error: SQL instance did not start as expected."
    }
}


