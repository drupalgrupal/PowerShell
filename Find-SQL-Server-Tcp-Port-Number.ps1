# See blog post: https://sqlpal.blogspot.com/p/find-sql-server-tcp-port-number-using.html

<#
The main focus of this little PowerShell script is to find tcp port number 
for a sql serve instance on a remote computer.

You can even run this against multiple servers, see the blog post
referenced above for details.


#>

$server_name       = 'SQLVM01.prod.domain.com'
$sql_instance_name = 'SQL2019AG01'


Function Get-sql-protocols
{
    Param 
    ([Parameter(Mandatory=$true)] [string]$p_instance_name)


$registry_path = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Depth 3  | Where-Object {$_.PSChildName -contains $p_instance_name}
$protocols_list = Get-ChildItem $registry_path.PSPath -Recurse | Where-Object {$_.PSChildName -eq 'SuperSocketNetLib'}

# Lets limit results to the Np, Sm and Tcp protocols
$protocols = Get-ChildItem $registry_path.PSPath -Recurse | Where-Object {$_.PSChildName -in ('Np', 'Sm', 'Tcp')}


$my_custom_object = @()
foreach ($protocol in $protocols)
{
    foreach($protocolp in $protocol.GetValueNames())
    {
        
        $my_custom_object += [PSCustomObject]@{
                sql_instance     = $p_instance_name
                protocol_name    = $protocol.PSChildName
                property_name    = $protocolp
                property_value   = $protocol.GetValue($protocolp)
            }
        
    }
}
$my_custom_object
}

if($server_name) {$sql_protocols = Invoke-Command -ComputerName $server_name   -ScriptBlock ${Function:Get-sql-protocols} -ArgumentList $sql_instance_name}
else             {$sql_protocols = Invoke-Command -ScriptBlock ${Function:Get-sql-protocols} -ArgumentList $sql_instance_name}
$sql_protocols | Select-Object PSComputerName, sql_instance, protocol_name, property_name | Format-Table -AutoSize

