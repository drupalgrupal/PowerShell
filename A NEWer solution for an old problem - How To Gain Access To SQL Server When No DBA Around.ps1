##### CAUTION: THE SCRIPT WILL STOP AND RESTART YOUR SQL SERVER INSTANCE!!!!!!!!!
<#
THIS SCRIPT IS INTENDED TO GET ACCESS TO SQL SERVER ONLY IF 
YOU DON'T HAVE SYSADMIN PERMISSION. SO ONLY USE THIS IN EMERGENCY

ON THE PLUS SIDE, IT HAS OPTION TO PROMPT YOU FOR CONFIRMATION BEFORE 
STOPPING THE SQL INSTANCE

REQUIREMENTS:.

1. YOU MUST HAVE THE LOCAL ADMINISTRATOR RIGHTS ON THE SERVER
2. YOU ARE RUNNING THE SCRIPT LOCALLY ON THE SERVER, OR 
   THROUGH THE INVOKE-COMMMAND CMDLET
3. THE POWERSHELL MUST BE LAUNCHED WITH ELEVATED ADMINISTRATIVE PRIVILEGES

PARAMETERS: ONLY THE FIRST PARAMETER, $login_to_be_granted_access, IS REQUIRED

1.  $login_to_be_granted_access --> This can be a Windows Login or SQL Login
                                    $sql_login_password is required for SQL Login

2.  $sql_instance_name -----------> Only specify the sql instance name without the server name
                                    If omitted, the default instance is assumed

3.  $confirm ---------------------> $true or $false to prompt for confirmation

Optional: Only required for SQL Login
4.  $sql_login_password ----------> Password for the SQL Login

#>
param (
  [string] $login_to_be_granted_access = 'sqladmin',
  [string] $sql_instance_name = 'SQL2022AG01',  
  [Boolean] $confirm = $true,
  [string] $sql_login_password = 'WA1!!1P7JRjN7F4eibEES&IxU%Elgw6b#'
)


# set the default preferences
$ErrorActionPreference = 'Stop'
$WarningPreference     = 'Continue'
$InformationPreference = 'Continue'

# if value for sql_instance_name is blnak then assume the default instance
if (-Not ($sql_instance_name)) {$sql_instance_name = 'MSSQLSERVER'}

# if value for $confirm is blank then assume $true
if ($confirm -eq $null) {$confirm = $true}


$msg = 'Computer Name: ' + $env:COMPUTERNAME
Write-Information $msg
$msg = 'SQL Instance Name: ' + $sql_instance_name
Write-Information $msg

Write-Information ""

# SHOW PROMPT IF $confirm IS TRUE
if ($confirm -eq $true)
{
    $valid_responses = "Yes", "yes", "No", "no"
    do {
        Write-Warning "##### CAUTION: THE SCRIPT WILL STOP AND RESTART YOUR SQL SERVER INSTANCE!!!!!!!!!"
        $response = Read-Host -Prompt "Are you sure you want to continue (Yes/No) ?"
        if(-not $valid_responses.Contains($response)){write-host "Please enter Yes or No"}
    } until ($valid_responses.Contains($response))

    if ($response -in ('No', 'no') )
    {
        return
    }
}
else
{
    Write-Warning '$confirm is false therefore all prompts will be suppressed.'
    Write-Information ""
}


# LETS DO A BIT OF VALIDATION
if (-not ($sql_instance_name) -or (-not ($login_to_be_granted_access)))
{
    Throw 'Error: Values for $sql_instance_name and $login_to_be_granted_access are required'
}

if (-not ($login_to_be_granted_access.Contains('\')) -and (-not ($sql_login_password)))
{
    Throw 'A password must be given for SQL Login'

}

# CHECK IF RUNNING POWERSHELL IN ELEVATED PRIVILEDGES MODE
if(-Not (([System.Security.Principal.WindowsIdentity]::GetCurrent()).Owner -eq "S-1-5-32-544"))
{
    Throw 'Error: Powershell must be launched in elevated privileges mode'
}


# GET THE NAME OF THE WINDOWS SERVICE AND THE SQL CONNECTION
if($sql_instance_name -eq "MSSQLSERVER")   # DEFAULT INSTANCE
{
    $service_name = 'MSSQLSERVER'
    $sql_server_instance = "."
}
else                                       # NAMED SQL INSTANCE 
{
    $service_name = "MSSQL`$$sql_instance_name"
    $sql_server_instance = ".\$sql_instance_name"
}


Write-Information "SQL Server: $sql_server_instance"
Write-Information "Serivce Name: $service_name"
Write-Information ""

# GET THE SERVICE OBJECT AND THE DEPENDENT SERVICES
$sql_service = Get-Service -Name $service_name
$dependent_services = $sql_service.DependentServices

# 
# EXTRA CHECK: STOP IF THE SERVICE IS NOT FOUND
if(-Not ($sql_service))
{
        Throw "Error: Please ensure the sql instance $sql_instance_name is valid and a windows service with name $service_name exists..."
}


$msg = "Service Status: " + ($sql_service.Status)
Write-Information $msg

$msg = "Service Startup Type: " + $sql_service.StartType
Write-Information $msg

Write-Information ""

# IF THE SERVICE IS DISABLED, PROMPT TO RE-ENABLE IT IN MANUAL MODE
if($sql_service.StartType -eq 'Disabled')
{

    Write-Warning "SQL Instance sql_instance_name is currently disabled...."
    
    if ($confirm) {Set-Service -Name $service_name -StartupType Manual -Confirm}
    else {Set-Service -Name $service_name -StartupType Manual}
    
    $sql_service.Refresh()

    if($sql_service.StartType -eq 'Disabled')
    {
           Throw "Error: Script cannot continue when SQL Instance is in Disabled mode."
    }


}

# STOP THE SERVICE ONLY IF IT IS RUNNING
# PROMPT TO CONFIRM BEFORE STOPPING THE SERVICE

if($sql_service.Status -eq 'Running')
{
    Write-Warning "Stopping service: $service_name"
    Write-Warning "Any dependent services will also be stopped..."
    
    if ($confirm) {Stop-Service -InputObject $sql_service -Confirm -Force}
    else {Stop-Service -InputObject $sql_service -Force}


    Write-Information ""
    Write-Information "STOP-SERVICE MAY RUN IN ASYNC MODE SO LETS SLEEP FOR FEW SECONDS..."
    Start-Sleep 5
    
    # CHECK TO MAKE SURE THE SERVICE IS NOW STOPPED 
    $sql_service.Refresh()

    if($sql_service.Status -ne "Stopped")
    {
        throw "Error: SQL instance service $service_name must be in stopped state before continuing...."
    }

}



#  A WINDOWS SERVICE CAN ONLY BE STARTED IF IT'S START UP TYPE IS MANUAL, AUTOMATIC OR DELAYED AUTOMATIC START 
#  SO, CONTINUE ONLY IF THE START UP TYPE IS NOT ONE OF THEM

$sql_service.Refresh()
if($sql_service.Status -ne 'Running' -and $sql_service.StartType -in ('Manual', 'Automatic'))
{
    
    Write-Warning  "Starting SQL Service in single user mode..."
    Write-Information ""
    net start $service_name /f /m
    Start-Sleep 2

    # CHECK TO MAKE SURE THE INSTANCE IS NOW RUNNING 
    $sql_service.Refresh()
    if($sql_service.Status -eq "Running")
    {

        if ($login_to_be_granted_access.Contains('\'))
        {
            $sql =  "CREATE LOGIN [$login_to_be_granted_access] FROM WINDOWS; ALTER SERVER ROLE sysadmin ADD MEMBER $login_to_be_granted_access; "
        }
        else
        {
            $sql = "CREATE LOGIN [$login_to_be_granted_access] WITH PASSWORD=N'$sql_login_password', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF"
            $sql += "; ALTER SERVER ROLE sysadmin ADD MEMBER $login_to_be_granted_access; "
        }


        $msg = "Adding $login_to_be_granted_access to the SYSADMIN role in SQL Server..."
        Write-Information $msg

        sqlcmd.exe -E -S $sql_server_instance -Q $sql

        Write-Information ""
        Write-Information "Restarting the SQL instance in normal mode..."
        net stop $service_name
        net start $service_name

        # Restart any dependenT service that were running... 
        foreach ($dependent_service in $dependent_services)
        {
            if($dependent_service.Status -eq 'Running')
            {
                $dependent_service_name = $dependent_service.Name
                
                # Check one more time to make sure it's not already running...
                if ((Get-Service -Name $dependent_service_name).Status -ne 'Running')
                {
                    $msg = "Starting dependent service: $dependent_service_name"
                    Write-Information $msg
                    $dependent_service.Start()
                }
            }


        }
    }
    else
    {
        Throw "Error: SQL Instance is not running...."
    }
}
