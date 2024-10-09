# See blog post: https://sqlpal.blogspot.com/2019/07/a-simple-powershell-script-to-look-up_23.html


# Specify the server name here

$server         = "server1"


# pull all the information
$hardware         = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $server
$OS               = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $server
$CPU              = Get-CimInstance -ClassName Win32_Processor -ComputerName $server
$PhysicalMemory   = Get-CimInstance -ClassName CIM_PhysicalMemory -ComputerName $server
$Bios             = Get-CimInstance -ClassName Win32_BIOS -ComputerName $server

$total_memory = ($PhysicalMemory | measure-object -Property Capacity -sum).sum
$total_memory_gb = $total_memory / 1024 / 1024 / 1024

# build custom array to get some key properties in a single row
$server_summary = New-Object PSObject

Add-Member -inputObject $server_summary -memberType NoteProperty -Name Manufacturer -value $hardware.Manufacturer
Add-Member -inputObject $server_summary -memberType NoteProperty -Name Model -value $hardware.Model
Add-Member -inputObject $server_summary -memberType NoteProperty -Name HypervisorPresent -value $hardware.HypervisorPresent
Add-Member -inputObject $server_summary -memberType NoteProperty -Name Bios -value $Bios.Name
Add-Member -inputObject $server_summary -memberType NoteProperty -Name OS -value $OS.Caption
Add-Member -inputObject $server_summary -memberType NoteProperty -Name OSArchitecture -value $OS.OSArchitecture
Add-Member -inputObject $server_summary -memberType NoteProperty -Name CPUs -value $CPU.count
Add-Member -inputObject $server_summary -memberType NoteProperty -Name PhySicalMemory_GB -value $total_memory_gb
Add-Member -inputObject $server_summary -memberType NoteProperty -Name OSVersionNumber -value $OS.Version
Add-Member -inputObject $server_summary -memberType NoteProperty -Name ServicePackMajorVersion -value $OS.ServicePackMajorVersion
Add-Member -inputObject $server_summary -memberType NoteProperty -Name ServicePackMinor -value $OS.ServicePackMinorVersion
Add-Member -inputObject $server_summary -memberType NoteProperty -Name LastBootUpTime -value $OS.LastBootUpTime

# Display the values

# First, lets up the buffer size first so we can see the complete output on the screen
$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size (500, 3000)

"summary"
"======="

$server_summary | fl

""
"Detailed Properties"
"==================="

"Hardware:"
$hardware       | ft -Property *

"Bios:"
$Bios           | ft -Property * 

"Operating System:"
$OS             | ft -Property *

"CPUs:" 
$CPU            | ft -Property * 

"Physical Memory:"
$PhysicalMemory | ft -property *

