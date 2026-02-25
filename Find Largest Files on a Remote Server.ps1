# -------------------------------------------------------------------------------------------------
# Script Name: Get-LargeRemoteFiles.ps1
# Description:
#   Retrieves and displays the top N largest files on one or more remote computers, with optional
#   filtering by file name, minimum size, and last modification date. Useful for locating large
#   or old backup files on SQL Server or other systems.
#
# See Blog Post:
#   https://sqlpal.blogspot.com/2023/08/remotely-check-disk-space-find-and-delete-large-files.html
#
# Usage Example:
#   This example finds the top 5 largest BAK files containing the word "FULL" on drive O:, that are
#   at least 100 MB in size and were last modified more than 8 days ago.
#
#   You can customize the parameters as needed or comment out filters to broaden the results.
# -------------------------------------------------------------------------------------------------

# -----------------------------
# User Configuration Section
# -----------------------------

# Name of the remote computer(s) to query. You can specify multiple names separated by commas.
$computer_name = @("SQLServer1")

# Target drive or folder path on the remote machine
$remote_folder = 'O:\'   

# Optionally, filter for file name pattern (use wildcards as needed)
$filter_by_name = '*.bak'

# Minimum file size filter, in bytes (100 * 1024 * 1024 = 100MB)
$filter_by_size = 100 * 1024 * 1024    

# Optionarlly, only include files last modified before this number of days ago
# NOTE: Use a negative number so (Get-Date).AddDays(-8) means "older than 8 days".
$filter_by_last_modified_before_days = -8 

# Limit the output to the top N largest files
$top_n = 5  

# -----------------------------
# Input Validation and Defaults
# -----------------------------

# Ensure the day filter value is negative; prevents confusion with positive inputs
if ($filter_by_last_modified_before_days -gt 0) {
    $filter_by_last_modified_before_days = $filter_by_last_modified_before_days * -1
}

# Set default values if variables are not provided
if ([string]::IsNullOrEmpty($top_n) -or $top_n -eq 0) { $top_n = 50 }
if ([string]::IsNullOrEmpty($filter_by_name)) { $filter_by_name = '*' }
if ([string]::IsNullOrEmpty($filter_by_size)) { $filter_by_size = 0 }
if ([string]::IsNullOrEmpty($filter_by_last_modified_before_days)) { $filter_by_last_modified_before_days = 0 }

# -----------------------------
# Resolve FQDN for Remote Computers
# -----------------------------
# Some servers may require fully-qualified domain names (FQDN) for remote commands.
$computer_fqdn = @()
foreach ($computer in $computer_name) {
    try {
        $computer_fqdn += @([System.Net.Dns]::GetHostEntry($computer).HostName)
    } catch {
        Write-Warning "Unable to resolve FQDN for $computer. Using provided name."
        $computer_fqdn += $computer
    }
}

# -----------------------------
# Invoke Remote Command
# -----------------------------
# Uses PowerShell Remoting to connect and scan the target directory.
# Requires WinRM enabled and appropriate credentials.
$large_files = @(
    Invoke-Command -ComputerName $computer_fqdn `
                   -ArgumentList $remote_folder, $filter_by_name, $filter_by_size, $top_n `
                   -ScriptBlock {
        # Enumerate all matching files recursively under $remote_folder
        Get-ChildItem $Using:remote_folder -Filter $Using:filter_by_name -Recurse `
                       -ErrorAction SilentlyContinue -Force |
        Where-Object { $_.Length -gt $Using:filter_by_size } |
        Sort-Object Length -Descending |
        Select-Object FullName,
            @{Name = "Size(GB)"; Expression = { [Math]::Round($_.Length / 1GB, 2) }},
            @{Name = "Size(MB)"; Expression = { [Math]::Round($_.Length / 1MB, 0) }},
            LastWriteTime `
        -First $Using:top_n
    }
)

# -----------------------------
# Display Results
# -----------------------------
# Sort output by Size(MB) for readability.
$large_files | Sort-Object -Property 'Size(MB)' -Descending |
    Format-Table PSComputerName, 'Size(MB)', 'Size(GB)', LastWriteTime, FullName

# Optionally, you can prepare a list of files to delete if they’re older than N days.
# Uncomment the following line if needed:
# $files_to_delete = $large_files | Where-Object { $_.LastWriteTime -lt ((Get-Date).AddDays($filter_by_last_modified_before_days)) } | Select-Object FullName

# Display total count for clarity
$large_files_count = $large_files.Count
"Number of files: $large_files_count"


