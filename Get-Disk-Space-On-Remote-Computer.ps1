# See blog post: https://sqlpal.blogspot.com/p/powershell-script-to-get-disk-space.html

# For example:
$computer_fqdn = "SQLVM01.MY.AD.DOMAIN"

Get-WMIObject  -ComputerName $computer_fqdn Win32_LogicalDisk -ErrorVariable ErrVar -ErrorAction SilentlyContinue | 
    Where-Object {$_.MediaType -eq 12} |
    Select-Object __SERVER,
                 @{n='DriveLetter';e={$_.Name}}, 
                 VolumeName,   
                 @{n='Capacity (Gb)' ;e={"{0:n0}" -f ($_.size/1gb)}},
                 @{n='FreeSpace (Gb)';e={"{0:n0}" -f ($_.freespace/1gb)}}, 
                 @{n='PercentFree';e={[Math]::round($_.freespace/$_.size*100)}} | 
    Format-Table -AutoSize 

