Windows PowerShell
Copyright (C) 2013 Microsoft Corporation. All rights reserved.

Adding VMware Snapin...
Complete
1 - Connect to jxfq-vc001.fanatics.corp
2 - Connect to togetheragain.evorigin.com
3 - No connection
Please make a selection: 2

Name                           Port  User
----                           ----  ----
togetheragain.evorigin.com     443   evorigin\cdupree


cdupree@FOOTBALLFANATIC Scripts> $VMs = Get-VM
cdupree@FOOTBALLFANATIC Scripts>
cdupree@FOOTBALLFANATIC Scripts> foreach ($VM in $VMs)
>> {
>> $VersionCap = $VM.Version
>> if ($VersionCap -eq "v8")
>> {
>> Shutdown-VMGuest $VM -Confirm:$false
>>
>> $NotOffYet = "true"
>>
>> while ($NotOffYet -eq "true")
>> {
>> start-sleep -s 10
>> $NotOffYet = "false"
>> ForEach ($VM in $WorkGroup)
>> {
>> $Check = (Get-VM -Name $VM | select PowerState)
>> if ($Check.PowerState -eq "PoweredOn")
>> {
>> $NotOffYet = "true"
>> }
>> }
>> Write-Host ""
>> Write-Host "VM shut down not complete..."
>> }
>>
>> start-sleep -s 10
>>
>> Set-VM -VM $VM -Version v9 -Confirm:$false
>>
>> start-sleep -s 10
>>
>> Start-VM $VM -Confirm:$false
>> }
>> }
>>

State          IPAddress            OSFullName
-----          ---------            ----------
Running        {192.167.1.101}      Microsoft Windows Server 2012 (64-bit)

VM shut down not complete...
WARNING: The 'Description' property of VirtualMachine type is deprecated. Use the 'Notes' property instead.
WARNING: The 'HardDisks' property of VirtualMachine type is deprecated. Use 'Get-HardDisk' cmdlet instead.
WARNING: The 'NetworkAdapters' property of VirtualMachine type is deprecated. Use 'Get-NetworkAdapter' cmdlet instead.
WARNING: The 'UsbDevices' property of VritualMachine type is deprecated. Use 'Get-UsbDevice' cmdlet instead.
WARNING: The 'CDDrives' property of VitrualMachine type is deprecated. Use 'Get-CDDrive' cmdlet instead.
WARNING: The 'FloppyDrives' property of VirtualMachine type is deprecated. Use 'Get-FloppyDrive' cmdlet instead.
WARNING: The 'Host' property of VirtualMachine type is deprecated. Use the 'VMHost' property instead.
WARNING: The 'HostId' property of VirtualMachine type is deprecated. Use the 'VMHostId' property instead.
WARNING: PowerCLI scripts should not use the 'Client' property. The property will be removed in a future release.

PowerState              : PoweredOff
Version                 : v9
Description             :
Notes                   :
Guest                   : DC01:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : Origin Domain
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v1002
ResourcePool            :
PersistentId            : 50370463-038a-481b-cf1c-9d9389960e1b
UsedSpaceGB             : 40.008361777290701866149902344
ProvisionedSpaceGB      : 44.218105755746364593505859375
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : DC01
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1141
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1141/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient


PowerState              : PoweredOn
Version                 : v9
Description             :
Notes                   :
Guest                   : DC01:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : Origin Domain
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v1002
ResourcePool            :
PersistentId            : 50370463-038a-481b-cf1c-9d9389960e1b
UsedSpaceGB             : 44.114807089790701866149902344
ProvisionedSpaceGB      : 44.114807568490505218505859375
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : DC01
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1141
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1141/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient

Running        {192.167.1.100}      Microsoft Windows Server 2012 (64-bit)

VM shut down not complete...

PowerState              : PoweredOff
Version                 : v9
Description             :
Notes                   :
Guest                   : DC02:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx1.evorigin.com
HostId                  : HostSystem-host-1136
VMHostId                : HostSystem-host-1136
VMHost                  : esx1.evorigin.com
VApp                    : Origin Domain
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v1002
ResourcePool            :
PersistentId            : 5037eac6-acae-2be7-400e-60a9151c96a7
UsedSpaceGB             : 40.001292572356760501861572266
ProvisionedSpaceGB      : 44.227130737155675888061523438
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : DC02
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1181
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1181/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient


PowerState              : PoweredOn
Version                 : v9
Description             :
Notes                   :
Guest                   : DC02:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx1.evorigin.com
HostId                  : HostSystem-host-1136
VMHostId                : HostSystem-host-1136
VMHost                  : esx1.evorigin.com
VApp                    : Origin Domain
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v1002
ResourcePool            :
PersistentId            : 5037eac6-acae-2be7-400e-60a9151c96a7
UsedSpaceGB             : 44.124339447356760501861572266
ProvisionedSpaceGB      : 44.124339904636144638061523438
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : DC02
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1181
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1181/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient

Running        {192.170.1.100}      Microsoft Windows Server 2008 R2 (64-bit)

VM shut down not complete...

PowerState              : PoweredOff
Version                 : v9
Description             :
Notes                   :
Guest                   : Eternal:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1, Hard disk 2}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx1.evorigin.com
HostId                  : HostSystem-host-1136
VMHostId                : HostSystem-host-1136
VMHost                  : esx1.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037aa07-191e-74d5-c3bf-9ec3e0045fe4
UsedSpaceGB             : 55.001364322379231452941894531
ProvisionedSpaceGB      : 59.227202973328530788421630859
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : Eternal
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1140
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1140/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient


PowerState              : PoweredOn
Version                 : v9
Description             :
Notes                   :
Guest                   : Eternal:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1, Hard disk 2}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx1.evorigin.com
HostId                  : HostSystem-host-1136
VMHostId                : HostSystem-host-1136
VMHost                  : esx1.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037aa07-191e-74d5-c3bf-9ec3e0045fe4
UsedSpaceGB             : 59.124411197379231452941894531
ProvisionedSpaceGB      : 59.124412140808999538421630859
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : Eternal
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1140
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1140/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient

Running        {192.168.1.107}      Microsoft Windows Server 2012 (64-bit)

VM shut down not complete...

PowerState              : PoweredOff
Version                 : v9
Description             :
Notes                   :
Guest                   : Lacrymosa:
NumCpu                  : 2
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1, Hard disk 2}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037cb63-602e-9dc3-fc08-2e26a180966c
UsedSpaceGB             : 60.001423975452780723571777344
ProvisionedSpaceGB      : 64.248308336362242698669433594
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/2000 MemShares:Normal/40960
Name                    : Lacrymosa
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1147
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1147/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient


PowerState              : PoweredOn
Version                 : v9
Description             :
Notes                   :
Guest                   : Lacrymosa:
NumCpu                  : 2
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1, Hard disk 2}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037cb63-602e-9dc3-fc08-2e26a180966c
UsedSpaceGB             : 64.108845850452780723571777344
ProvisionedSpaceGB      : 64.108846819028258323669433594
DatastoreIdList         : {Datastore-datastore-804}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/2000 MemShares:Normal/40960
Name                    : Lacrymosa
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1147
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1147/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient

Running        {192.168.1.117, f... Microsoft Windows Server 2012 (64-bit)

VM shut down not complete...

PowerState              : PoweredOff
Version                 : v9
Description             :
Notes                   :
Guest                   : OpenManage:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037a6cd-3e9e-076f-77c8-29fdddb55457
UsedSpaceGB             : 40.104168056510388851165771484
ProvisionedSpaceGB      : 44.313912019133567810058593750
DatastoreIdList         : {Datastore-datastore-1130}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : OpenManage
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1132
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1132/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient


PowerState              : PoweredOn
Version                 : v9
Description             :
Notes                   :
Guest                   : OpenManage:
NumCpu                  : 1
MemoryMB                : 4096
MemoryGB                : 4
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {}
Host                    : esx2.evorigin.com
HostId                  : HostSystem-host-1129
VMHostId                : HostSystem-host-1129
VMHost                  : esx2.evorigin.com
VApp                    : SQL Apps
FolderId                :
Folder                  :
ResourcePoolId          : VirtualApp-resgroup-v921
ResourcePool            :
PersistentId            : 5037a6cd-3e9e-076f-77c8-29fdddb55457
UsedSpaceGB             : 44.210613369010388851165771484
ProvisionedSpaceGB      : 44.210613831877708435058593750
DatastoreIdList         : {Datastore-datastore-1130}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/40960
Name                    : OpenManage
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1132
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1132/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient

Running        {192.168.1.254, f... FreeBSD (64-bit)

VM shut down not complete...
Set-VM : 8/9/2014 10:34:55 PM    Set-VM        The operation for the entity "pfSense" failed with the following message: "The operation is not allowed in the current state."
At line:24 char:1
+ Set-VM -VM $VM -Version v9 -Confirm:$false
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Set-VM], InvalidState
    + FullyQualifiedErrorId : Client20_TaskServiceImpl_CheckServerSideTaskUpdates_OperationFailed,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVM


PowerState              : PoweredOn
Version                 : v8
Description             :
Notes                   :
Guest                   : pfSense:
NumCpu                  : 1
MemoryMB                : 512
MemoryGB                : 0.5
HardDisks               : {Hard disk 1}
NetworkAdapters         : {Network adapter 1, Network adapter 2, Network adapter 3, Network adapter 4}
UsbDevices              : {}
CDDrives                : {CD/DVD drive 1}
FloppyDrives            : {Floppy drive 1}
Host                    : esx3.evorigin.com
HostId                  : HostSystem-host-1121
VMHostId                : HostSystem-host-1121
VMHost                  : esx3.evorigin.com
VApp                    :
FolderId                : Folder-group-v1071
Folder                  : Discovered virtual machine
ResourcePoolId          : ResourcePool-resgroup-1070
ResourcePool            : Resources
PersistentId            : 5037279f-1a05-0e08-b98a-848001488764
UsedSpaceGB             : 8.589530836790800094604492188
ProvisionedSpaceGB      : 8.589530836790800094604492188
DatastoreIdList         : {Datastore-datastore-1122}
HARestartPriority       : ClusterRestartPriority
HAIsolationResponse     : AsSpecifiedByCluster
DrsAutomationLevel      : AsSpecifiedByCluster
VMSwapfilePolicy        : Inherit
VMResourceConfiguration : CpuShares:Normal/1000 MemShares:Normal/5120
Name                    : pfSense
CustomFields            : {}
ExtensionData           : VMware.Vim.VirtualMachine
Id                      : VirtualMachine-vm-1128
Uid                     : /VIServer=evorigin\cdupree@togetheragain.evorigin.com:443/VirtualMachine=VirtualMachine-vm-1128/
Client                  : VMware.VimAutomation.ViCore.Impl.V1.VimClient



cdupree@FOOTBALLFANATIC Scripts> $VM = Get-VM solitude
cdupree@FOOTBALLFANATIC Scripts> Get-VMGuestNetworkInterface $VM
Get-VMGuestNetworkInterface : 8/9/2014 10:39:26 PM    Get-VMGuestNetworkInterface        Failed to authenticate with the guest operating system using the supplied credentials.
At line:1 char:1
+ Get-VMGuestNetworkInterface $VM
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Get-VMGuestNetworkInterface], InvalidGuestLogin
    + FullyQualifiedErrorId : Client20_VmGuestServiceImpl_GetGuestAuthentication_ViError,VMware.VimAutomation.ViCore.Cmdlets.Commands.GetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> $creds = Get-Credential

cmdlet Get-Credential at command pipeline position 1
Supply values for the following parameters:
Credential
cdupree@FOOTBALLFANATIC Scripts> Get-VMGuestNetworkInterface $VM -credential $creds
Get-VMGuestNetworkInterface : A parameter cannot be found that matches parameter name 'credential'.
At line:1 char:33
+ Get-VMGuestNetworkInterface $VM -credential $creds
+                                 ~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Get-VMGuestNetworkInterface], ParameterBindingException
    + FullyQualifiedErrorId : NamedParameterNotFound,VMware.VimAutomation.ViCore.Cmdlets.Commands.GetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> Get-VMGuestNetworkInterface $VM -guestcredential $creds

VM              Name                      IP              IPPolicy   SubnetMask
--              ----                      --              --------   ----------
Solitude        Local Area Connection     192.168.1.111   Static     255.255.255.0
Solitude        isatap.evorigin.com                       Static
Solitude        Local Area Connection* 9                  Static


cdupree@FOOTBALLFANATIC Scripts> Get-VMGuestNetworkInterface $VM -guestcredential $creds | where {$_.IP -ne $NULL}

VM              Name                      IP              IPPolicy   SubnetMask
--              ----                      --              --------   ----------
Solitude        Local Area Connection     192.168.1.111   Static     255.255.255.0


cdupree@FOOTBALLFANATIC Scripts> $NIC = Get-VMGuestNetworkInterface $VM -guestcredential $creds | where {$_.IP -ne $NULL}
cdupree@FOOTBALLFANATIC Scripts> $NIC

VM              Name                      IP              IPPolicy   SubnetMask
--              ----                      --              --------   ----------
Solitude        Local Area Connection     192.168.1.111   Static     255.255.255.0


cdupree@FOOTBALLFANATIC Scripts> $NIC | GM


   TypeName: VMware.VimAutomation.ViCore.Impl.V1.VMGuestNetworkInterfaceImpl

Name             MemberType Definition
----             ---------- ----------
ConvertToVersion Method     T ConvertToVersion[T](), T VersionedObjectInterop.ConvertToVersion[T]()
Equals           Method     bool Equals(System.Object obj)
GetHashCode      Method     int GetHashCode()
GetType          Method     type GetType()
IsConvertableTo  Method     bool IsConvertableTo(type toType), bool VersionedObjectInterop.IsConvertableTo(type type)
ToString         Method     string ToString()
Client           Property   VMware.VimAutomation.ViCore.Interop.V1.VIAutomation Client {get;}
DefaultGateway   Property   string DefaultGateway {get;}
Description      Property   string Description {get;}
Dns              Property   string[] Dns {get;}
DnsPolicy        Property   System.Nullable[VMware.VimAutomation.ViCore.Types.V1.DhcpPolicy] DnsPolicy {get;}
Ip               Property   string Ip {get;}
IPPolicy         Property   VMware.VimAutomation.ViCore.Types.V1.DhcpPolicy IPPolicy {get;}
Mac              Property   string Mac {get;}
Name             Property   string Name {get;}
NetworkAdapter   Property   VMware.VimAutomation.ViCore.Types.V1.VirtualDevice.NetworkAdapter NetworkAdapter {get;}
NetworkAdapterId Property   string NetworkAdapterId {get;}
NicId            Property   string NicId {get;}
RouteInterfaceId Property   string RouteInterfaceId {get;}
SubnetMask       Property   string SubnetMask {get;}
Uid              Property   string Uid {get;}
VM               Property   VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine VM {get;}
VMId             Property   string VMId {get;}
Wins             Property   string[] Wins {get;}
WinsPolicy       Property   System.Nullable[VMware.VimAutomation.ViCore.Types.V1.DhcpPolicy] WinsPolicy {get;}


cdupree@FOOTBALLFANATIC Scripts> $NIC.dns
192.168.1.101
cdupree@FOOTBALLFANATIC Scripts> help Set-VMGuestNetworkInterface

NAME
    Set-VMGuestNetworkInterface

SYNOPSIS
    This cmdlet configures the network settings of a virtual machine using VMware Tools.


SYNTAX
    Set-VMGuestNetworkInterface -VmGuestNetworkInterface <VMGuestNetworkInterface[]> [-WinsPolicy <DhcpPolicy>] [-Wins <String[]>] [-DnsPolicy <DhcpPolicy>] [-Dns <String[]>] [-IPPolicy
    <DhcpPolicy>] [[-Gateway] <Object>] [[-Netmask] <String>] [[-Ip] <IPAddress>] [-ToolsWaitSecs <Int32>] [-GuestPassword <SecureString>] [-GuestUser <String>] [-GuestCredential <PSCredential>]
    [-HostPassword <SecureString>] [-HostUser <String>] [-HostCredential <PSCredential>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This cmdlet configures the network settings of a virtual machine using VMware Tools. The cmdlet allows IP and routing configuration. You can modify Wins settings only for Windows virtual
    machines. The cmdlet sends a remote script which executes inside the virtual machine in the context of the specified user account. This cmdlet supports only Windows XP 32 SP3, Windows Server
    2003 32bit SP2, Windows Server 2003 64bit SP2, Windows 7 64 bit, Windows Server 2008 R2 64bit and Redhat Enterprise 5 operating systems.

    To run this cmdlet against vCenter Server/ESX/ESXi versions earlier than 5.0, you need to meet the following requirements:
    *You must run the cmdlet on the 32-bit version of Windows PowerShell.
    *You must have access to the ESX that hosts the virtual machine over TCP port 902.
    *For vCenter Server/ESX/ESXi versions earlier than 4.1, you need VirtualMachine.Interact.ConsoleInteract privilege. For vCenter Server/ESX/ESXi 4.1 and later, you need
    VirtualMachine.Interact.GuestControl privilege.

    To run this cmdlet against vCenter Server/ESXi 5.0 and later, you need VirtualMachine.GuestOperations.Execute and VirtualMachine.GuestOperations.Modify privileges.


RELATED LINKS
    Online version: http://www.vmware.com/support/developer/PowerCLI/PowerCLI55R1/html/Set-VMGuestNetworkInterface.html
    Get-VMGuestNetworkInterface

REMARKS
    To see the examples, type: "get-help Set-VMGuestNetworkInterface -examples".
    For more information, type: "get-help Set-VMGuestNetworkInterface -detailed".
    For technical information, type: "get-help Set-VMGuestNetworkInterface -full".
    For online help, type: "get-help Set-VMGuestNetworkInterface -online"




cdupree@FOOTBALLFANATIC Scripts> Set-VMGuestNetworkInterface $NIC -Dns "192.168.1.101,192.168.1.100"
Set-VMGuestNetworkInterface : Cannot bind parameter 'Ip'. Cannot convert the "Local Area Connection" value of type "VMware.VimAutomation.ViCore.Impl.V1.VMGuestNetworkInterfaceImpl" to type
"System.Net.IPAddress".
At line:1 char:29
+ Set-VMGuestNetworkInterface $NIC -Dns "192.168.1.101,192.168.1.100"
+                             ~~~~
    + CategoryInfo          : InvalidArgument: (:) [Set-VMGuestNetworkInterface], ParameterBindingException
    + FullyQualifiedErrorId : CannotConvertArgumentNoMessage,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> $NIC.GetType()

IsPublic IsSerial Name                                     BaseType
-------- -------- ----                                     --------
True     False    VMGuestNetworkInterfaceImpl              VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl


cdupree@FOOTBALLFANATIC Scripts> Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101,192.168.1.100"
Set-VMGuestNetworkInterface : The parameter 'Dns' is invalid.
At line:1 char:1
+ Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101,19 ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Set-VMGuestNetworkInterface], ViError
    + FullyQualifiedErrorId : VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViError,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101","192.168.1.100"
Set-VMGuestNetworkInterface : 8/9/2014 10:49:26 PM    Set-VMGuestNetworkInterface        Failed to authenticate with the guest operating system using the supplied credentials.
At line:1 char:1
+ Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101"," ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Set-VMGuestNetworkInterface], InvalidGuestLogin
    + FullyQualifiedErrorId : Client20_VmGuestServiceImpl_GetGuestAuthentication_ViError,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101","192.168.1.100" -GuestCredential $creds
Set-VMGuestNetworkInterface : 8/9/2014 10:50:17 PM    Set-VMGuestNetworkInterface        "Error occured while configuring the network:'Access is denied.
The requested operation requires elevation (Run as administrator).
The requested operation requires elevation (Run as administrator).
'.
At line:1 char:1
+ Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101"," ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Set-VMGuestNetworkInterface], ViError
    + FullyQualifiedErrorId : Client20_VmGuestService_SetVmGuestNetworkInterface_Error,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts> $creds

UserName                                                                                                                                                                                       Password
--------                                                                                                                                                                                       --------
evorigin\da-cdupree                                                                                                                                                        System.Security.SecureString


cdupree@FOOTBALLFANATIC Scripts> Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101","192.168.1.100" -GuestCredential $creds
Set-VMGuestNetworkInterface : 8/9/2014 11:02:12 PM    Set-VMGuestNetworkInterface        "Error occured while configuring the network:'Access is denied.
The requested operation requires elevation (Run as administrator).
The requested operation requires elevation (Run as administrator).
'.
At line:1 char:1
+ Set-VMGuestNetworkInterface -VmGuestNetworkInterface $NIC -Dns "192.168.1.101"," ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidArgument: (:) [Set-VMGuestNetworkInterface], ViError
    + FullyQualifiedErrorId : Client20_VmGuestService_SetVmGuestNetworkInterface_Error,VMware.VimAutomation.ViCore.Cmdlets.Commands.SetVmGuestNetworkInterface

cdupree@FOOTBALLFANATIC Scripts>