#Import-Module Az.Storage -MinimumVersion 1.7.0 -Scope Local
Param(
        [Parameter(Mandatory=$True)][System.String] $ResourceGroupName,
        [Parameter(Mandatory=$True)][System.String] $StorageAccountName,
        [Parameter(Mandatory=$True)][System.String] $FileShareName,
        [Parameter(Mandatory=$True)][System.String] $SubscriptionId,
        [Parameter(Mandatory=$True)][System.String] $SnapshotName,
        [Parameter(Mandatory=$False)][System.Boolean] $DeleteSnapshot=$False
    )

Function Break-SnapshotLease
{
    Param(
        [Parameter(Mandatory=$True)][Microsoft.WindowsAzure.Commands.Common.Storage.LazyAzureStorageContext] $Context,
        [Parameter(Mandatory=$True)][System.String] $FileShareName,
        [Parameter(Mandatory=$True)][System.String] $SnapshotName
        )

    if ([string]::IsNullOrWhiteSpace($FileShareName))
    {
        Write-Error "Please specify the required input parameter: FileShareName" -ErrorAction Stop
    }
    if ([string]::IsNullOrWhiteSpace($SnapshotName))
    {
        Write-Error "Please specify the required input parameter: SnapshotName" -ErrorAction Stop
    }

    $FileShareName = $FileShareName.ToLowerInvariant()

    Write-Verbose "Attempting to break lease on the snapshot: fileShareName = $FileShareName, snapshotName = $SnapshotName" -Verbose

    Write-Information -MessageData "Started: Creating SASToken to fetch lease state of the snapshot" -InformationAction Continue

    $getLeaseStateToken = New-AzStorageAccountSASToken -Context $Context -Service File -ResourceType Container -Permission "r" -Protocol HttpsOrHttp -StartTime (Get-Date).AddHours(-1) -ExpiryTime (Get-Date).AddHours(1)

    Write-Information -MessageData "Completed: Creating SASToken to fetch lease state of the snapshot" -InformationAction Continue

    Write-Information -MessageData "Started: Checking lease state of the snapshot" -InformationAction Continue

    $getLeaseStateUrl = [string]::Concat($Context.FileEndPoint, $FileShareName, "?restype=share&sharesnapshot=", $SnapshotName, "&api-version=2020-02-10&", $getLeaseStateToken.Substring(1))

    $getLeaseStateResponse = Invoke-WebRequest $getLeaseStateUrl -Method "GET" -Verbose

    $leaseState = "leased"

    if ($getLeaseStateResponse.StatusCode -ne 200)
    {
        Write-Error "Checking lease state of the snapshot failed. Attempting to break lease anyway." -ErrorAction Continue
    }
    else
    {
        $leaseState = $getLeaseStateResponse.Headers["x-ms-lease-state"]
        Write-Information -MessageData "Fetched lease State: $leaseState" -InformationAction Continue
    }

    if($leaseState -eq "leased")
    {
        Write-Information -MessageData "Started: Creating SASToken to break lease on the snapshot" -InformationAction Continue

        $breakLeaseToken = New-AzStorageAccountSASToken -Context $Context -Service File -ResourceType Container -Permission "w" -Protocol HttpsOrHttp -StartTime (Get-Date).AddHours(-1) -ExpiryTime (Get-Date).AddHours(1)

        Write-Information -MessageData "Completed: Creating SASToken to break lease on the snapshot" -InformationAction Continue

        Write-Information -MessageData "Started: Breaking lease on the snapshot" -InformationAction Continue

        $breakLeaseUrl = [string]::Concat($Context.FileEndPoint, $FileShareName, "?restype=share&comp=lease&sharesnapshot=", $SnapshotName, "&api-version=2020-02-10&", $breakLeaseToken.Substring(1))

        $breakLeaseHeaders = @{"x-ms-lease-action" = "break"}

        $breakLeaseResponse = Invoke-WebRequest $breakLeaseUrl -Headers $breakLeaseHeaders -Method "PUT" -Verbose

        if ($breakLeaseResponse.StatusCode -ne 202)
        {
            Write-Error "Request to break lease on the snapshot failed." -ErrorAction Continue
        }

        Write-Verbose $breakLeaseResponse.RawContent -Verbose

        Write-Information -MessageData "Completed: Breaking lease on the snapshot" -InformationAction Continue
    }
    else
    {
        Write-Information "No need to break lease as snapshot is not in leased state." -InformationAction Continue
    }
    
}

Connect-AzAccount
Select-AzSubscription -Subscription $SubscriptionId
$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName

$snapshot = Get-AzStorageShare -Context $sa.Context -Name $FileShareName -SnapshotTime $SnapshotName

if($snapshot.IsSnapshot -ne $true)
{
    Write-Error "This is not a snapshot but an actual file share" -ErrorAction Stop
}

$isAzureBackupSnapshot = ($snapshot.ShareProperties.Metadata -ne $null -and $snapshot.ShareProperties.Metadata.ContainsKey("Initiator") -and $snapshot.ShareProperties.Metadata["Initiator"] -eq "AzureBackup")

if($isAzureBackupSnapshot -ne $true)
{
    Write-Error "This is not a snapshot created by Azure Backup" -ErrorAction Stop
}

Break-SnapshotLease $sa.Context $FileShareName $SnapshotName

if($DeleteSnapshot -eq $True)
{
    Write-Information -MessageData "Started: Deleting the snapshot." -InformationAction Continue

    Remove-AzStorageShare -Share $snapshot.CloudFileShare -Verbose -Force

    Write-Information -MessageData "Completed: Deleting the snapshot." -InformationAction Continue
}
else
{
    Write-Information -MessageData "Not attempting to delete the snapshot as DeleteSnapshot flag is not set to true." -InformationAction Continue
}
