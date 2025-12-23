
# Convert-OciInventoryToExcel.ps1
[CmdletBinding()]
param(
    [string]$InputJson = "oci-inventory.json",
    [string]$OutputXlsx = "oci_inventory.xlsx"
)

Import-Module ImportExcel -ErrorAction Stop

function Expand-Object {
    param([object]$Obj)

    if ($Obj -is [pscustomobject]) {
        $h = @{}
        foreach ($p in $Obj.PSObject.Properties) {
            $val = $p.Value
            if ($val -is [pscustomobject]) {
                # Flatten one level
                foreach ($ip in $val.PSObject.Properties) {
                    $h["$($p.Name).$($ip.Name)"] = $ip.Value
                }
            } elseif ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
                # Arrays -> JSON string to preserve structure in Excel cell
                $h[$p.Name] = ($val | ConvertTo-Json -Compress)
            } else {
                $h[$p.Name] = $val
            }
        }
        return [pscustomobject]$h
    } elseif ($Obj -is [hashtable]) {
        return pscustomobject
    } else {
        return $Obj
    }
}

function Flatten-Hashtable {
    param([hashtable]$Hash)
    $flat = @{}
    foreach ($k in $Hash.Keys) {
        $v = $Hash[$k]
        if ($v -is [hashtable]) {
            foreach ($innerK in $v.Keys) { $flat["$k.$innerK"] = $v[$innerK] }
        } elseif ($v -is [System.Collections.IEnumerable] -and -not ($v -is [string])) {
            $flat[$k] = ($v | ConvertTo-Json -Compress)
        } else {
            $flat[$k] = $v
        }
    }
    return $flat
}

if (-not (Test-Path $InputJson)) { throw "Input JSON file not found: $InputJson" }

$inv = Get-Content -Raw -Path $InputJson | ConvertFrom-Json

$tables = @(
    @{ Name = "Compartments";     Items = $inv.compartments },
    @{ Name = "VCNs";             Items = $inv.networking.vcns },
    @{ Name = "Subnets";          Items = $inv.networking.subnets },
    @{ Name = "Instances";        Items = $inv.compute.instances },
    @{ Name = "Volumes";          Items = $inv.storage.volumes },
    @{ Name = "Boot Volumes";     Items = $inv.storage.boot_volumes },
    @{ Name = "Buckets";          Items = $inv.storage.buckets },
    @{ Name = "Load Balancers";   Items = $inv.load_balancing.load_balancers },
    @{ Name = "Users";            Items = $inv.identity.users },
    @{ Name = "Groups";           Items = $inv.identity.groups },
    @{ Name = "Policies";         Items = $inv.identity.policies }
)

# Build the Excel file — create/overwrite
if (Test-Path $OutputXlsx) { Remove-Item $OutputXlsx -Force }

foreach ($t in $tables) {
    $items = @()    
    $rows = if ($null -eq $t.Items) { @() } else { $t.Items }
    foreach ($row in $rows) 
    {
        $items += Expand-Object -Obj $row
    }
    if ($items.Count -gt 0) {
        $items | Export-Excel -Path $OutputXlsx -WorksheetName $t.Name -AutoSize `
                              -FreezeTopRow -BoldTopRow `
                              -TableName ($t.Name -replace '\s+', '') `
                              -ClearSheet
        Write-Host "Wrote sheet: $($t.Name)"
    }
}


Write-Host "Excel created: $OutputXlsx"
