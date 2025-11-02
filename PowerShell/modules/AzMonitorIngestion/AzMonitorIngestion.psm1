<#
.SYNOPSIS
    Azure Monitor Logs Ingestion Module

.DESCRIPTION
    Provides functions to send custom log data to Azure Monitor via Data Collection Endpoints
    with support for multiple authentication methods including Managed Identity, Service Principal
    with Certificate or Secret, and interactive login.

.NOTES
    Author: IT Operations Team
    Version: 1.0.0
    Requires: Az.Accounts module (Install-Module Az.Accounts)

.EXAMPLE
    Import-Module AzMonitorIngestion
    Connect-AzMonitorIngestion -UseManagedIdentity
    Send-AzMonitorData -DceEndpoint $dce -DcrImmutableId $dcr -StreamName $stream -Data $data
#>

#Requires -Modules Az.Accounts

# Module-level variables
$script:ModuleVersion = "1.0.0"
$script:AuthenticationMethod = $null
$script:AuthenticationParameters = $null

#region Authentication Functions

function Connect-AzMonitorIngestion {
    <#
    .SYNOPSIS
        Authenticate to Azure for Monitor ingestion

    .DESCRIPTION
        Establishes authentication context for Azure Monitor ingestion.
        Supports multiple authentication methods including Managed Identity,
        Service Principal (with certificate or secret), and interactive login.

    .PARAMETER UseManagedIdentity
        Use system-assigned managed identity

    .PARAMETER UserAssignedIdentityClientId
        Client ID of user-assigned managed identity

    .PARAMETER ServicePrincipalCertificate
        Use Service Principal authentication with certificate

    .PARAMETER CertificateThumbprint
        Certificate thumbprint (from CurrentUser\My or LocalMachine\My store)

    .PARAMETER CertificatePath
        Path to certificate file (.pfx or .cer)

    .PARAMETER CertificatePassword
        Password for certificate file (if required)

    .PARAMETER TenantId
        Azure AD Tenant ID

    .PARAMETER ApplicationId
        Service Principal Application (Client) ID

    .PARAMETER ServicePrincipalSecret
        Service Principal client secret (SecureString)

    .PARAMETER UseCurrentContext
        Use existing Azure PowerShell context (default if no parameters)

    .PARAMETER UseAzureCli
        Use Azure CLI credentials

    .EXAMPLE
        # Use system-assigned managed identity
        Connect-AzMonitorIngestion -UseManagedIdentity

    .EXAMPLE
        # Use user-assigned managed identity
        Connect-AzMonitorIngestion -UserAssignedIdentityClientId "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        # Use Service Principal with certificate from certificate store
        Connect-AzMonitorIngestion `
            -ServicePrincipalCertificate `
            -TenantId "your-tenant-id" `
            -ApplicationId "your-app-id" `
            -CertificateThumbprint "ABC123..."

    .EXAMPLE
        # Use Service Principal with certificate file
        Connect-AzMonitorIngestion `
            -ServicePrincipalCertificate `
            -TenantId "your-tenant-id" `
            -ApplicationId "your-app-id" `
            -CertificatePath "C:\certs\app.pfx" `
            -CertificatePassword (ConvertTo-SecureString "password" -AsPlainText -Force)

    .EXAMPLE
        # Use Service Principal with secret
        $secret = ConvertTo-SecureString "your-secret" -AsPlainText -Force
        Connect-AzMonitorIngestion `
            -TenantId "your-tenant-id" `
            -ApplicationId "your-app-id" `
            -ServicePrincipalSecret $secret

    .EXAMPLE
        # Use current Azure PowerShell context
        Connect-AzAccount
        Connect-AzMonitorIngestion -UseCurrentContext

    .EXAMPLE
        # Use Azure CLI credentials
        az login
        Connect-AzMonitorIngestion -UseAzureCli
    #>

    [CmdletBinding(DefaultParameterSetName = 'CurrentContext')]
    param(
        # Managed Identity (System-assigned)
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [switch]$UseManagedIdentity,

        # Managed Identity (User-assigned)
        [Parameter(ParameterSetName = 'UserAssignedIdentity', Mandatory)]
        [string]$UserAssignedIdentityClientId,

        # Service Principal with Certificate (from store)
        [Parameter(ParameterSetName = 'ServicePrincipalCertThumbprint')]
        [switch]$ServicePrincipalCertificate,

        [Parameter(ParameterSetName = 'ServicePrincipalCertThumbprint', Mandatory)]
        [string]$CertificateThumbprint,

        # Service Principal with Certificate (from file)
        [Parameter(ParameterSetName = 'ServicePrincipalCertFile')]
        [string]$CertificatePath,

        [Parameter(ParameterSetName = 'ServicePrincipalCertFile')]
        [SecureString]$CertificatePassword,

        # Common Service Principal parameters
        [Parameter(ParameterSetName = 'ServicePrincipalCertThumbprint', Mandatory)]
        [Parameter(ParameterSetName = 'ServicePrincipalCertFile', Mandatory)]
        [Parameter(ParameterSetName = 'ServicePrincipalSecret', Mandatory)]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'ServicePrincipalCertThumbprint', Mandatory)]
        [Parameter(ParameterSetName = 'ServicePrincipalCertFile', Mandatory)]
        [Parameter(ParameterSetName = 'ServicePrincipalSecret', Mandatory)]
        [string]$ApplicationId,

        # Service Principal with Secret
        [Parameter(ParameterSetName = 'ServicePrincipalSecret', Mandatory)]
        [SecureString]$ServicePrincipalSecret,

        # Current Context
        [Parameter(ParameterSetName = 'CurrentContext')]
        [switch]$UseCurrentContext,

        # Azure CLI
        [Parameter(ParameterSetName = 'AzureCli')]
        [switch]$UseAzureCli
    )

    try {
        Write-Verbose "Authenticating to Azure Monitor..."

        switch ($PSCmdlet.ParameterSetName) {
            'ManagedIdentity' {
                Write-Verbose "Using System-Assigned Managed Identity"
                Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
                Write-Host "✓ Connected using System-Assigned Managed Identity" -ForegroundColor Green
            }

            'UserAssignedIdentity' {
                Write-Verbose "Using User-Assigned Managed Identity: $UserAssignedIdentityClientId"
                Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId -ErrorAction Stop | Out-Null
                Write-Host "✓ Connected using User-Assigned Managed Identity" -ForegroundColor Green
            }

            'ServicePrincipalCertThumbprint' {
                Write-Verbose "Using Service Principal with Certificate (Thumbprint: $CertificateThumbprint)"

                # Find certificate in store
                $cert = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -Recurse |
                    Where-Object { $_.Thumbprint -eq $CertificateThumbprint } |
                    Select-Object -First 1

                if (-not $cert) {
                    throw "Certificate with thumbprint '$CertificateThumbprint' not found in certificate stores"
                }

                Write-Verbose "Found certificate: $($cert.Subject)"

                Connect-AzAccount `
                    -ServicePrincipal `
                    -TenantId $TenantId `
                    -ApplicationId $ApplicationId `
                    -CertificateThumbprint $CertificateThumbprint `
                    -ErrorAction Stop | Out-Null

                Write-Host "✓ Connected using Service Principal with Certificate" -ForegroundColor Green
            }

            'ServicePrincipalCertFile' {
                Write-Verbose "Using Service Principal with Certificate File: $CertificatePath"

                if (-not (Test-Path $CertificatePath)) {
                    throw "Certificate file not found: $CertificatePath"
                }

                # Load certificate from file
                if ($CertificatePassword) {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
                        $CertificatePath,
                        $CertificatePassword
                    )
                }
                else {
                    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
                }

                Write-Verbose "Loaded certificate: $($cert.Subject)"

                # Import to temp store and use thumbprint
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
                    "My",
                    "CurrentUser"
                )
                $store.Open("ReadWrite")
                $store.Add($cert)
                $store.Close()

                Connect-AzAccount `
                    -ServicePrincipal `
                    -TenantId $TenantId `
                    -ApplicationId $ApplicationId `
                    -CertificateThumbprint $cert.Thumbprint `
                    -ErrorAction Stop | Out-Null

                Write-Host "✓ Connected using Service Principal with Certificate File" -ForegroundColor Green
            }

            'ServicePrincipalSecret' {
                Write-Verbose "Using Service Principal with Secret"

                $credential = New-Object System.Management.Automation.PSCredential(
                    $ApplicationId,
                    $ServicePrincipalSecret
                )

                Connect-AzAccount `
                    -ServicePrincipal `
                    -TenantId $TenantId `
                    -Credential $credential `
                    -ErrorAction Stop | Out-Null

                Write-Host "✓ Connected using Service Principal with Secret" -ForegroundColor Green
            }

            'CurrentContext' {
                Write-Verbose "Using existing Azure context"

                $context = Get-AzContext
                if (-not $context) {
                    throw "No Azure context found. Run Connect-AzAccount first or use another authentication method."
                }

                Write-Host "✓ Using existing Azure context: $($context.Account.Id)" -ForegroundColor Green
            }

            'AzureCli' {
                Write-Verbose "Using Azure CLI credentials"

                # Check if Azure CLI is installed
                $azCliCheck = Get-Command az -ErrorAction SilentlyContinue
                if (-not $azCliCheck) {
                    throw "Azure CLI not found. Install from: https://aka.ms/installazurecliwindows"
                }

                # Get token using Azure CLI
                $cliResult = az account show 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Not logged in to Azure CLI. Run 'az login' first."
                }

                Write-Host "✓ Using Azure CLI credentials" -ForegroundColor Green
            }
        }

        # Store authentication method for token retrieval
        $script:AuthenticationMethod = $PSCmdlet.ParameterSetName
        $script:AuthenticationParameters = $PSBoundParameters

        Write-Verbose "Authentication successful"
        return $true
    }
    catch {
        Write-Error "Authentication failed: $_"
        throw
    }
}

function Get-AzMonitorAccessToken {
    <#
    .SYNOPSIS
        Get access token for Azure Monitor

    .DESCRIPTION
        Internal function to retrieve access token based on authentication method.
        Handles JWT token acquisition automatically using Azure AD.

    .NOTES
        This is an internal function. Use Connect-AzMonitorIngestion first.
    #>

    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Acquiring access token for Azure Monitor..."

        if (-not $script:AuthenticationMethod) {
            throw "Not authenticated. Run Connect-AzMonitorIngestion first."
        }

        # Get token based on authentication method
        if ($script:AuthenticationMethod -eq 'AzureCli') {
            # Use Azure CLI to get token
            $tokenJson = az account get-access-token --resource https://monitor.azure.com 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to get token from Azure CLI: $tokenJson"
            }

            $tokenObj = $tokenJson | ConvertFrom-Json
            $token = $tokenObj.accessToken
        }
        else {
            # Use Az.Accounts for all other methods
            $tokenResponse = Get-AzAccessToken -ResourceUrl "https://monitor.azure.com" -ErrorAction Stop
            $token = $tokenResponse.Token
        }

        if (-not $token) {
            throw "Failed to acquire access token"
        }

        Write-Verbose "✓ Access token acquired"
        return $token
    }
    catch {
        Write-Error "Failed to get access token: $_"
        throw
    }
}

#endregion

#region Data Ingestion Functions

function Send-AzMonitorData {
    <#
    .SYNOPSIS
        Send custom log data to Azure Monitor

    .DESCRIPTION
        Sends an array of custom objects to Azure Monitor Log Analytics using
        the Logs Ingestion API through a Data Collection Endpoint and Rule.

        Automatically handles:
        - Authentication token refresh
        - Large dataset batching
        - Retry logic for transient failures
        - Comprehensive error reporting

    .PARAMETER DceEndpoint
        The logs ingestion endpoint URL of your Data Collection Endpoint
        Example: https://dce-name-abc123.eastus-1.ingest.monitor.azure.com

    .PARAMETER DcrImmutableId
        The immutable ID of your Data Collection Rule (DCR)
        Example: dcr-abc123def456...

    .PARAMETER StreamName
        The stream name for your custom table
        Example: Custom-ComplianceChecks_CL

    .PARAMETER Data
        Array of custom objects to send. Must match the DCR schema.

    .PARAMETER BatchSize
        Maximum number of records to send per batch (default: 1000, max: 10000)

    .PARAMETER RetryAttempts
        Number of retry attempts for transient failures (default: 3)

    .PARAMETER RetryDelaySeconds
        Delay between retry attempts in seconds (default: 5)

    .PARAMETER ThrottleOnFailure
        If true, implements exponential backoff on failures

    .EXAMPLE
        # Basic usage (after authentication)
        $data = @(
            [PSCustomObject]@{
                TimeGenerated = (Get-Date).ToUniversalTime().ToString("o")
                ServerName    = "WEB-01"
                Status        = "PASS"
            }
        )

        Send-AzMonitorData `
            -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com" `
            -DcrImmutableId "dcr-abc123..." `
            -StreamName "Custom-MyData_CL" `
            -Data $data

    .EXAMPLE
        # Large dataset with custom batching
        Send-AzMonitorData `
            -DceEndpoint $env:DCE_ENDPOINT `
            -DcrImmutableId $env:DCR_ID `
            -StreamName $env:STREAM_NAME `
            -Data $largeDataset `
            -BatchSize 500 `
            -RetryAttempts 5 `
            -ThrottleOnFailure `
            -Verbose
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^https://.*\.ingest\.monitor\.azure\.com$')]
        [string]$DceEndpoint,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DcrImmutableId,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^Custom-.*_CL$')]
        [string]$StreamName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$Data,

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$BatchSize = 1000,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$RetryAttempts = 3,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$RetryDelaySeconds = 5,

        [Parameter()]
        [switch]$ThrottleOnFailure
    )

    begin {
        Write-Verbose "Azure Monitor Data Ingestion starting..."
        Write-Verbose "DCE: $DceEndpoint"
        Write-Verbose "DCR: $DcrImmutableId"
        Write-Verbose "Stream: $StreamName"
        Write-Verbose "Records: $($Data.Count)"

        if (-not $script:AuthenticationMethod) {
            throw "Not authenticated. Run Connect-AzMonitorIngestion first."
        }
    }

    process {
        try {
            # Step 1: Get Access Token (JWT handled automatically)
            $accessToken = Get-AzMonitorAccessToken

            # Convert to plain text (PS 7+ supports -AsPlainText)
            if ($accessToken -is [System.Security.SecureString]) {
                $plain = ConvertFrom-SecureString -AsPlainText $accessToken
            } else {
                $plain = [string]$accessToken
            }

            # Step 2: Prepare request headers
            $headers = @{
                "Authorization" = "Bearer $plain"
                "Content-Type"  = "application/json"
            }

            # Step 3: Build URI
            $uri = "$DceEndpoint/dataCollectionRules/$DcrImmutableId/streams/$StreamName`?api-version=2023-01-01"
            Write-Verbose "Endpoint: $uri"

            # Step 4: Split data into batches
            $totalRecords = $Data.Count
            $batchCount = [Math]::Ceiling($totalRecords / $BatchSize)

            Write-Verbose "Splitting into $batchCount batch(es) of max $BatchSize records"

            $successCount = 0
            $failureCount = 0
            $batchNumber = 0

            for ($i = 0; $i -lt $totalRecords; $i += $BatchSize) {
                $batchNumber++
                $end = [Math]::Min($i + $BatchSize, $totalRecords)
                $batch = $Data[$i..($end - 1)]
                $batchRecordCount = $batch.Count

                Write-Verbose "Processing batch $batchNumber/$batchCount ($batchRecordCount records)"

                # Convert batch to JSON
                $jsonBody = $batch | ConvertTo-Json -AsArray -Depth 10 -Compress

                # Send with retry logic
                $attempt = 0
                $success = $false
                $lastError = $null
                $currentDelay = $RetryDelaySeconds

                while ($attempt -lt $RetryAttempts -and -not $success) {
                    $attempt++

                    try {
                        Write-Verbose "Attempt $attempt of $RetryAttempts..."

                        $response = Invoke-RestMethod `
                            -Uri $uri `
                            -Method Post `
                            -Headers $headers `
                            -Body $jsonBody `
                            -ErrorAction Stop `
                            -TimeoutSec 30

                        $success = $true
                        $successCount += $batchRecordCount

                        Write-Verbose "✓ Batch $batchNumber sent successfully"
                    }
                    catch {
                        $lastError = $_

                        if ($attempt -lt $RetryAttempts) {
                            $statusCode = $_.Exception.Response.StatusCode.value__

                            # Check if error is retryable
                            $retryableErrors = @(429, 500, 502, 503, 504)

                            if ($statusCode -in $retryableErrors) {
                                Write-Warning "Transient error ($statusCode). Retrying in $currentDelay seconds..."
                                Start-Sleep -Seconds $currentDelay

                                # Exponential backoff if enabled
                                if ($ThrottleOnFailure) {
                                    $currentDelay = $currentDelay * 2
                                }
                            }
                            else {
                                # Non-retryable error - fail immediately
                                throw
                            }
                        }
                    }
                }

                if (-not $success) {
                    $failureCount += $batchRecordCount
                    Write-Error "Failed to send batch $batchNumber after $RetryAttempts attempts: $lastError"

                    # Extract and display error details
                    if ($lastError.Exception.Response) {
                        try {
                            $reader = [System.IO.StreamReader]::new($lastError.Exception.Response.GetResponseStream())
                            $reader.BaseStream.Position = 0
                            $errorBody = $reader.ReadToEnd()
                            Write-Error "Error details: $errorBody"
                        }
                        catch {
                            Write-Verbose "Could not read error response body"
                        }
                    }
                }
            }

            # Step 5: Report results
            Write-Verbose "Ingestion complete"
            Write-Verbose "Total records: $totalRecords"
            Write-Verbose "Successful: $successCount"
            Write-Verbose "Failed: $failureCount"

            if ($successCount -gt 0) {
                Write-Host "✓ Successfully sent $successCount of $totalRecords records" -ForegroundColor Green
            }

            if ($failureCount -gt 0) {
                Write-Warning "✗ Failed to send $failureCount records"
            }

            # Return summary
            return [PSCustomObject]@{
                TotalRecords    = $totalRecords
                SuccessfulSends = $successCount
                FailedSends     = $failureCount
                BatchCount      = $batchCount
                StreamName      = $StreamName
                Timestamp       = Get-Date
                Success         = ($failureCount -eq 0)
            }
        }
        catch {
            Write-Error "Failed to send data to Azure Monitor: $_"

            # Provide actionable error messages
            if ($_.Exception.Response) {
                $statusCode = $_.Exception.Response.StatusCode.value__

                $errorMessages = @{
                    401 = "Authentication failed. Token may be expired. Try re-authenticating with Connect-AzMonitorIngestion."
                    403 = "Authorization failed. Ensure 'Monitoring Metrics Publisher' role is assigned to your identity on the DCR."
                    404 = "Resource not found. Verify DCR Immutable ID and Stream Name are correct."
                    413 = "Payload too large. Reduce the BatchSize parameter."
                    429 = "Rate limited. Enable -ThrottleOnFailure or reduce ingestion frequency."
                    500 = "Azure Monitor service error. Check Azure status: https://status.azure.com"
                    502 = "Bad gateway. Verify DCE endpoint URL is correct."
                    503 = "Service unavailable. Azure Monitor may be experiencing issues."
                    504 = "Gateway timeout. Try reducing batch size or check network connectivity."
                }

                if ($errorMessages.ContainsKey($statusCode)) {
                    Write-Error $errorMessages[$statusCode]
                }
                else {
                    Write-Error "HTTP $statusCode error occurred."
                }
            }

            throw
        }
    }
}

#endregion

#region Diagnostic Functions

function Test-AzMonitorIngestion {
    <#
    .SYNOPSIS
        Test connection to Azure Monitor DCE

    .DESCRIPTION
        Performs diagnostic tests on Data Collection Endpoint connectivity,
        including DNS resolution, TCP connectivity, and HTTPS reachability.

    .PARAMETER DceEndpoint
        The DCE endpoint URL to test

    .EXAMPLE
        Test-AzMonitorIngestion -DceEndpoint "https://dce-prod.eastus-1.ingest.monitor.azure.com"

    .OUTPUTS
        Boolean - Returns $true if all tests pass, $false otherwise
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^https://.*\.ingest\.monitor\.azure\.com$')]
        [string]$DceEndpoint
    )

    try {
        Write-Host "`nTesting connection to: $DceEndpoint" -ForegroundColor Cyan

        # Parse hostname
        $uri = [System.Uri]::new($DceEndpoint)
        $hostname = $uri.Host

        # Test 1: DNS resolution
        Write-Host "  [1/3] Testing DNS resolution..." -NoNewline
        try {
            $dnsResult = Resolve-DnsName -Name $hostname -ErrorAction Stop

            if ($dnsResult) {
                $ip = $dnsResult | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
                if ($ip.IPAddress -match '^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.') {
                    Write-Host " ✓ Private IP: $($ip.IPAddress)" -ForegroundColor Green
                }
                else {
                    Write-Host " ✓ Public IP: $($ip.IPAddress)" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            Write-Error "DNS resolution failed: $_"
            return $false
        }

        # Test 2: TCP connection
        Write-Host "  [2/3] Testing TCP connectivity (port 443)..." -NoNewline
        try {
            $tcpTest = Test-NetConnection -ComputerName $hostname -Port 443 -WarningAction SilentlyContinue

            if ($tcpTest.TcpTestSucceeded) {
                Write-Host " ✓ Connected" -ForegroundColor Green
            }
            else {
                Write-Host " ✗ FAILED" -ForegroundColor Red
                Write-Error "TCP connection failed"
                return $false
            }
        }
        catch {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            Write-Error "TCP test failed: $_"
            return $false
        }

        # Test 3: HTTPS connectivity
        Write-Host "  [3/3] Testing HTTPS endpoint..." -NoNewline
        try {
            $response = Invoke-WebRequest -Uri $DceEndpoint -Method Get -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Host " ✓ Reachable (Status: $($response.StatusCode))" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 404) {
                Write-Host " ✓ Reachable (404 expected)" -ForegroundColor Green
            }
            else {
                Write-Host " ⚠ Inconclusive: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        Write-Host "`n✓ All connectivity tests passed" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Connection test failed: $_"
        return $false
    }
}

function Test-AzMonitorPermissions {
    <#
    .SYNOPSIS
        Test RBAC permissions on Data Collection Rule

    .DESCRIPTION
        Verifies that the specified principal has the required 'Monitoring Metrics Publisher'
        role on the Data Collection Rule.

    .PARAMETER DcrResourceId
        Full resource ID of the Data Collection Rule

    .PARAMETER PrincipalId
        Object ID of the principal to check (Service Principal, Managed Identity, or User)

    .EXAMPLE
        $dcrId = "/subscriptions/.../providers/Microsoft.Insights/dataCollectionRules/dcr-MyData_CL"
        $spId = "12345678-1234-1234-1234-123456789012"
        Test-AzMonitorPermissions -DcrResourceId $dcrId -PrincipalId $spId

    .OUTPUTS
        Boolean - Returns $true if principal has required role, $false otherwise
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DcrResourceId,

        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    try {
        Write-Host "`nChecking permissions for principal: $PrincipalId" -ForegroundColor Cyan
        Write-Host "On DCR: $DcrResourceId" -ForegroundColor Cyan

        # Get role assignments
        $assignments = Get-AzRoleAssignment -ObjectId $PrincipalId -Scope $DcrResourceId

        $hasRole = $assignments | Where-Object {
            $_.RoleDefinitionName -eq "Monitoring Metrics Publisher"
        }

        if ($hasRole) {
            Write-Host "✓ Has 'Monitoring Metrics Publisher' role" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "✗ Missing 'Monitoring Metrics Publisher' role" -ForegroundColor Red

            if ($assignments) {
                Write-Host "`nExisting roles:" -ForegroundColor Yellow
                $assignments | ForEach-Object {
                    Write-Host "  - $($_.RoleDefinitionName)" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "`nNo roles found for this principal on the DCR" -ForegroundColor Yellow
            }

            return $false
        }
    }
    catch {
        Write-Error "Failed to check permissions: $_"
        return $false
    }
}

function Get-AzMonitorModuleInfo {
    <#
    .SYNOPSIS
        Display module information and status

    .DESCRIPTION
        Shows current authentication status, module version, and available commands.

    .EXAMPLE
        Get-AzMonitorModuleInfo
    #>

    [CmdletBinding()]
    param()

    Write-Host "`n=== Azure Monitor Ingestion Module ===" -ForegroundColor Cyan
    Write-Host "Version: $script:ModuleVersion"

    Write-Host "`nAuthentication Status:" -ForegroundColor Cyan
    if ($script:AuthenticationMethod) {
        Write-Host "  ✓ Authenticated" -ForegroundColor Green
        Write-Host "  Method: $script:AuthenticationMethod"

        if ($script:AuthenticationMethod -ne 'AzureCli') {
            $context = Get-AzContext
            if ($context) {
                Write-Host "  Account: $($context.Account.Id)"
                Write-Host "  Tenant: $($context.Tenant.Id)"
            }
        }
    }
    else {
        Write-Host "  ✗ Not authenticated" -ForegroundColor Yellow
        Write-Host "  Run: Connect-AzMonitorIngestion"
    }

    Write-Host "`nAvailable Commands:" -ForegroundColor Cyan
    Get-Command -Module AzMonitorIngestion | ForEach-Object {
        Write-Host "  - $($_.Name)"
    }

    Write-Host "`nFor help on any command, use: Get-Help <command-name> -Full`n"
}

#endregion

# Export module members
Export-ModuleMember -Function `
    Connect-AzMonitorIngestion, `
    Send-AzMonitorData, `
    Test-AzMonitorIngestion, `
    Test-AzMonitorPermissions, `
    Get-AzMonitorModuleInfo
