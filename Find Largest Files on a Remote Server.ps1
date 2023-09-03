# See Blog Post: https://sqlpal.blogspot.com/2023/08/remotely-check-disk-space-find-and-delete-large-files.html

<#
In below example,  I am looking for top 5 largest files in O:\ containing *FULL*.BAK in the 
file name and at least larger than 100MB and last modified date is at least before 8 days. 
You can change the filter values to your needs and if you don't want to use a filter, 
just comment it out by putting the hash sign (#) in front it. And lastly, 
don't forget to change the value for $computer_name variable to your server name. 
You can also enter multiple server names, separated by a comma, for example:
#>

# Name of the remote computer
$computer_name = @("SQLServer1")
 
# Drive letter or a subfolder on a drive to search for the large sizes
$remote_folder = 'O:\'   

# Add optional filters
$filter_by_name = '*FULL*.BAK'
$filter_by_size = 100*1024*1024    # 100*1024*1024 = 100MB
$filter_by_last_modified_before_days = -8 # Note the minus (-) sign

$top_n = 5  # Limit the results to the top n files by size
# Make sure the $filter_by_last_modified_before_days is a negative value
if($filter_by_last_modified_before_days -gt 0) {$filter_by_last_modified_before_days = $filter_by_last_modified_before_days * -1}

# Set the filters to default values if not already Set by the caller
if($top_n -eq $null -or $top_n -eq 0 -or $top_n -eq '') {$top_n=50}
if($filter_by_name -eq $null -or $filter_by_name -eq '') {$filter_by_name='*'}
if($filter_by_size -eq $null -or $filter_by_size -eq '') {$filter_by_size=0}
if($filter_by_last_modified_before_days -eq $null -or $filter_by_last_modified_before_days -eq '') 
{$filter_by_last_modified_before_days=0}


# Lets get the fqdn for the remote computer
$computer_fqdn = @()
foreach($computer in $computer_name){$computer_fqdn += @([System.Net.Dns]::GetHostEntry($computer).HostName)}


$large_files = @(Invoke-Command -computername $computer_fqdn -ArgumentList $remote_folder, $filter_by_name, $filter_by_size, $top_n  `
               -scriptBlock {Get-ChildItem $Using:remote_folder -Filter $Using:filter_by_name  -recurse -ErrorAction SilentlyContinue –Force | 
                             where-object {$_.length -gt $Using:filter_by_size} | 
                             Sort-Object length -Descending | 
                             select   fullname, 
                                      @{Name="Size(GB)";Expression={[Math]::round($_.length / 1GB, 2)}}, 
                                      @{Name="Size(MB)";Expression={[Math]::round($_.length / 1MB, 0)}}, 
                                      LastWriteTime `
                             -First $Using:top_n
                            }  
                )
# Display
$large_files | sort -Property 'Size(MB)'  -Descending | ft PSComputerName, 'Size(MB)', 'Size(GB)', LastWriteTime, FullName

#$files_to_delete = $large_files | where-object {$_.LastWriteTime -lt ((Get-date).AddDays($filter_by_last_modified_before_days))} | select FullName

$large_files_count = $large_files.Count
"Number of files: $large_files_count"
