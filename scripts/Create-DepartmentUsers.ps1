# Phase 2.4 - Bulk user creation (5 real-named users per department)
# Idempotent: skips users that already exist
# Run as Domain Admin on the DC

# ---------- CONFIGURATION ----------
$DefaultPassword = "TempP@ssw0rd2026!"
$DomainDN   = (Get-ADDomain).DistinguishedName
$DomainName = (Get-ADDomain).DNSRoot

# Base OU path where the department folders live (adjust if your structure differs)
$BaseOU = "OU=Users,OU=ITSO,$DomainDN"

# ---------- DEPARTMENT -> OU NAME MAPPING ----------
# Update these to match your exact OU names / security group names
$DepartmentOUs = @{
    "Finance"       = "finance"
    "HR"            = "HR_USERS"
    "IT"            = "IT-USERS"
    "Sales"         = "SALES_USERS"
    "Administration"= "Admin_users"
}

# ---------- USER LIST (5 real-sounding names per department) ----------
$Users = @(
    # Finance
    @{First="Michael";  Last="Turner";     Department="Finance"},
    @{First="Sarah";    Last="Bennett";    Department="Finance"},
    @{First="David";    Last="Coleman";    Department="Finance"},
    @{First="Laura";    Last="Mitchell";   Department="Finance"},
    @{First="James";    Last="Reynolds";   Department="Finance"},

    # HR
    @{First="Emily";    Last="Parker";     Department="HR"},
    @{First="Daniel";   Last="Foster";     Department="HR"},
    @{First="Olivia";   Last="Bryant";     Department="HR"},
    @{First="Ryan";     Last="Simmons";    Department="HR"},
    @{First="Natalie";  Last="Hughes";     Department="HR"},

    # IT
    @{First="Kevin";    Last="Walsh";      Department="IT"},
    @{First="Jennifer"; Last="Ortiz";      Department="IT"},
    @{First="Brian";    Last="Nguyen";     Department="IT"},
    @{First="Rachel";   Last="Morgan";     Department="IT"},
    @{First="Tom";      Last="Whitfield";  Department="IT"},

    # Sales
    @{First="Chris";    Last="Palmer";     Department="Sales"},
    @{First="Megan";    Last="Ford";       Department="Sales"},
    @{First="Andrew";   Last="Barnes";     Department="Sales"},
    @{First="Jessica";  Last="Hayes";      Department="Sales"},
    @{First="Nathan";   Last="Cross";      Department="Sales"},

    # Administration
    @{First="Steven";   Last="Wallace";    Department="Administration"},
    @{First="Amanda";   Last="Price";      Department="Administration"},
    @{First="Jason";    Last="Fuller";     Department="Administration"},
    @{First="Karen";    Last="Douglas";    Department="Administration"},
    @{First="Eric";     Last="Marsh";      Department="Administration"}
)

# ---------- CREATION LOOP ----------
$Created = 0
$Skipped = 0
$Failed  = 0

foreach ($U in $Users) {
    $FirstName   = $U.First
    $LastName    = $U.Last
    $Department  = $U.Department
    $OUName      = $DepartmentOUs[$Department]
    $SamName     = ($FirstName.Substring(0,1) + $LastName).ToLower()
    $UPN         = "$SamName@$DomainName"
    $DisplayName = "$FirstName $LastName"
    $TargetOU    = "OU=$OUName,$BaseOU"

    # Idempotency check
    if (Get-ADUser -Filter "SamAccountName -eq '$SamName'" -ErrorAction SilentlyContinue) {
        Write-Host "SKIP: $DisplayName ($SamName) already exists" -ForegroundColor Yellow
        $Skipped++
        continue
    }

    try {
        New-ADUser `
            -Name              $DisplayName `
            -GivenName         $FirstName `
            -Surname           $LastName `
            -SamAccountName    $SamName `
            -UserPrincipalName $UPN `
            -DisplayName       $DisplayName `
            -EmailAddress      $UPN `
            -Department        $Department `
            -Path              $TargetOU `
            -AccountPassword   (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force) `
            -Enabled           $true `
            -ChangePasswordAtLogon $true `
            -ErrorAction Stop

        # Add to matching security group if it exists (group name assumed same as OU name)
        if (Get-ADGroup -Filter "Name -eq '$OUName'" -ErrorAction SilentlyContinue) {
            Add-ADGroupMember -Identity $OUName -Members $SamName -ErrorAction Stop
        }

        Write-Host "OK:   $DisplayName ($SamName) -> $Department" -ForegroundColor Green
        $Created++
    }
    catch {
        Write-Host "FAIL: $DisplayName ($SamName) - $($_.Exception.Message)" -ForegroundColor Red
        $Failed++
    }
}

Write-Host ""
Write-Host "===== SUMMARY =====" -ForegroundColor Cyan
Write-Host "Created: $Created"   -ForegroundColor Green
Write-Host "Skipped: $Skipped"   -ForegroundColor Yellow
Write-Host "Failed:  $Failed"    -ForegroundColor Red
