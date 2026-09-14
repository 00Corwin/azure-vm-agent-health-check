# Azure VM Agent Health Check

PowerShell diagnostics for Windows Azure VM Agent problems, including service
state, agent processes, OS disk free space, Azure WireServer connectivity,
WinHTTP proxy state, and the tail of `WaAppAgent.log`.

The WireServer address `168.63.129.16` is the Azure platform virtual IP used by
Azure guests. It is intentionally retained because it is not an organisation
address.

## Example

```powershell
.\Test-AzureVmAgentHealth.ps1 `
    -LogTail 200 `
    -OutputPath .\AzureVmAgentHealth.json
```

Run from an elevated PowerShell session on the affected Azure VM.
