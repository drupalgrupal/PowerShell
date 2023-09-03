# Related blog post:  https://sqlpal.blogspot.com/2019/07/powershell-script-to-get-list-of.html


try
{

        Import-Module -Name SqlServer

        $server_name   = "Server1"    # SERVER/HOST NAME HERE
        $database_name = "admin"      # NAME OF THE DATABASE YOU WOULD LIKE TO SEARCH OTHERWISE LEAVE THIS BLANK
        $exact_match   = "N"          # WHETHER TO SEARCH FOR AN EXACT DATABASE NAME


        # if $server_name string is empty or null then use the current computer name
        if ($server_name -eq "" -or $server_name -eq $null)
        {
                $server_name = $env:computername
        }

        "Looking up SQL Services on: $server_name"
        $sql_services = Get-WmiObject -Query "select * from win32_service
        where PathName like '%%sqlservr.exe%%'"  -ComputerName "$server_name" -ErrorAction Stop
        

        if ($sql_services.PSComputerName -ne $null)
        {
                # Display sql services on the screen

                $sql_services  |  select-object -Property PSComputerName, @{n="sql_instance";e={$_.Name -replace "MSSQL\$", ""}}, Name, ProcessID, StartMode, State, Status, ExitCode, PathName | ft -AutoSize


                foreach ($sql_service in $sql_services) 
                {

                        ""
                        $instnace_name = $sql_service.Name -replace "MSSQL\$", ""
                        "Instnace Name: " + $instnace_name

                        if ($instnace_name -eq "MSSQLSERVER") 
                
                        {
                                $sql_connection = $sql_service.PSComputerName
                        }

                        else 
                        {
                                $sql_connection = $sql_service.PSComputerName + "\" + $instnace_name
                        }

                        $sql_connection + ": " + $sql_service.State

                        if ($sql_service.State -eq "Running")
                        {
                                if ($database_name -eq "")
                                {
                                        Get-SqlDatabase -ServerInstance $sql_connection 
                                }
                                else
                                {
                                        if ($exact_match -eq "Y")
                                        {
                                                Get-SqlDatabase -ServerInstance $sql_connection | where {$_.name -eq $database_name} |  ft -AutoSize
                                        }
                                        else
                                        {
                                                Get-SqlDatabase -ServerInstance $sql_connection | where {$_.name -like "*$database_name*"} | ft -AutoSize
                                        }
                                }
                        }
                        else
                        {
                                "Skipping $sql_connection as its not running..."
                        }

                }
        }
}

Catch
{
        (Get-Date).ToString() + ": Error Occurred" 
        throw $_  
        return
}

