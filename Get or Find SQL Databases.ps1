# Related blog post:  https://sqlpal.blogspot.com/2019/07/powershell-script-to-get-list-of.html

try
{
    Import-Module -Name SqlServer -ErrorAction Stop

    $server_name   = "Server1" # SERVER/HOST NAME HERE  
    $database_name = "admin"   # NAME OF THE DATABASE YOU WOULD LIKE TO SEARCH OTHERWISE LEAVE THIS BLANK
    $exact_match   = "N"       # WHETHER TO SEARCH FOR AN EXACT DATABASE NAME

    $logfile = "$env:TEMP\logfile_" + (Get-Date).toString("yyyyMMdd_HHmmss") + ".txt"
    
    "Start Time: " + (Get-Date)  | Out-File -Append $logFile
    "Log: $logfile"  | Out-File -Append $logFile
    ""  | Out-File -Append $logFile
    "Server: $server_name" | Out-File -Append $logFile
    "Database: $database_name" | Out-File -Append $logFile
    "Exact Match: $exact_match" | Out-File -Append $logFile
    ""  | Out-File -Append $logFile


    if ($server_name -eq "" -or $server_name -eq $null)
    {
        $server_name = $env:computername
    }

    $sql_services = Get-WmiObject -Query "select * from win32_service where PathName like '%%sqlservr.exe%%'" -ComputerName "$server_name" -ErrorAction Stop

    foreach ($sql_service in $sql_services) 
    {
        $instance_name = $sql_service.Name -replace "MSSQL\$", ""
        if ($sql_service.State -eq "Running")
        {
            $sql_connection = if ($instance_name -eq "MSSQLSERVER") { $sql_service.PSComputerName } else { $sql_service.PSComputerName + "\" + $instance_name }

            if ($database_name -eq "")
            {
                Get-SqlDatabase -ServerInstance $sql_connection | 
                    FT Parent, Name, Owner, ReadOnly, RecoveryModel, Size, Status, UserAccess
            }
            else
            {

                if ($exact_match -eq "Y")
                {
                    Get-SqlDatabase -ServerInstance $sql_connection | Where-Object {$_.name -eq $database_name} | 
                        FT Parent, Name, Owner, ReadOnly, RecoveryModel, Size, Status, UserAccess
                }
                else
                {
                    Get-SqlDatabase -ServerInstance $sql_connection | Where-Object {$_.name -like "*$database_name*"} | 
                        FT Parent, Name, Owner, ReadOnly, RecoveryModel, Size, Status, UserAccess
                }
            }


        }
        else
        {
            "Skipping $sql_connection as it's not running..." | Out-File -Append $logFile
        }
    }

    ""  | Out-File -Append $logFile
    "Completion Time: " + (Get-Date)  | Out-File -Append $logFile
  
}
Catch
{
    $errorMessage = (Get-Date).ToString() + ": Error Occurred - " + $_.Exception.Message
    $errorMessage | Out-File -Append $logFile
    throw
}

"# Launch the notepad.exe to view the log file"
"notepad.exe $logfile"


