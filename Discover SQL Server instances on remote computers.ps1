<#


This powershell script uses WMI to connect to the each server and 
check windows services that matches %%sqlservr.exe%% pattern.
Therefore in order for this to work you would need to have access 
to the servers otherwise it will throw Access Denied errors. 
However since I am getting the list of servers to check from a CSV, 
it will continue on to the next server after the errors.


At the end it displays list of servers it successfully connected 
to and a separate list where it errored out.


It also exports the list of sql instances it discovered to a CSV file.

By default it uses the connected users credentials.
Though, there is option ($user variable) to specify a different 
credentials (Windows).  The password field is in plain text so 
I am not a big fan of it.

#>
(Get-Date).ToString() + ": Begin" 
try
{

        $user = ""           # Should be in Domain\UserName format
        $pass = ""
        

        if ($user -eq "") { $user = $Null}


        # If user/pass pair is provided, authenticate it against the domain
        if ($user-ne $Null)
        {
            "Authenticating user $user against AD domain"
            $domain = $user.Split("{\}")[0] 
            $domainObj = "LDAP://" + (Get-ADDomain $domain).DNSRoot 
            $domainObj
            
            $domainBind = New-Object System.DirectoryServices.DirectoryEntry($domainObj,$user,$pass)
            $domainDN = $domainBind.distinguishedName 
            "domain DN: " + $domainDN
            
            # Abort completely if the user authentication failed for some reason
            If ($domainDN -eq $Null) 
               {
                       "Please check the password and ensure the user exists and is enabled in domain: $domain"
                       throw "Error authenticating the user: $user"
                       exit
               }
            else {"The account $user successfully authenticated against the domain: $domain"}

            $passWord = ConvertTo-SecureString -String $pass -AsPlainText -Force
            $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $passWord
        }

        $csv_file_name = "new_servers.csv"
        $CSVData = Import-CSV $csv_file_name
        $export_file_name = "sql_server_instances.csv"
        $csv_row_count = $CSVData.Count
        (Get-Date).ToString() + ": Total rows in the CSV file: " + $csv_row_count
        $servers = $CSVData.DNSHostName

        $SqlInstancesList = @()
        $ErrorServers = @()
        ""
        $servers
        ""
        
        # iterate through each server and search for sql services on them

        foreach($server in $servers) 

        { 

            ""
            "Searching for SQL Server DB services on: $server"
        try
        {

                If (-Not (Test-Connection -ComputerName $server -Count 2 -Quiet))
                    {Throw "Invalid Computer Name: $server"}

                If ($user-ne $Null)
                   {$SqlServices = Get-WmiObject -Query "select * from win32_service where PathName like '%%sqlservr.exe%%'"  -credential $credentials  -ComputerName $server -ErrorAction Continue}
                Else
                   {$SqlServices = Get-WmiObject -Query "select * from win32_service where PathName like '%%sqlservr.exe%%'"  -ComputerName $server -ErrorAction Continue}
                
                $SqlInstancesList += $SqlServices
                
                "Number of SQL instances found on $server : " + $SqlInstancesList.Count | Write-Host -ForegroundColor Green
        }
        catch
        {
                # even though error occured, it will continue to the next server
                $em = $_.Exception.Message
                "Skipping $server because an error encountered ($em):" | Write-Host -ForegroundColor Yellow
                $ErrorServers += $server + " (" + $em + ")"
               
        }
        } 

        # if there were any errors with any of the servers, print off names of those servers along with the error message/reason
        if ($ErrorServers.Count -gt 0)
        {
                ""
                "Error when looking up SQL Instances on following servers:"  | Write-Host -ForegroundColor Red
                "--------------------------------------------------------"
                $ErrorServers
        }

        ""
        "EXPORTING TO FILE: $export_file_name"
        $SqlInstancesList | select-object -Property PSComputerName, @{n="SqlInstance";e={$_.Name -replace "MSSQL\$", ""}}, Name, ProcessID, StartMode, State, Status, ExitCode, PathName | Export-CSV $export_file_name -NoTypeInformation -Encoding UTF8

        ""
        "SQL Instances Found:" | Write-Host -ForegroundColor Green
        "--------------------"

        Import-Csv -Encoding UTF8 -Path $export_file_name | ft -AutoSize
        (Get-Date).ToString() + ": Complete" 
}
 
Catch
{
    (Get-Date).ToString() + ": Error Occurred" 
     throw  
}
