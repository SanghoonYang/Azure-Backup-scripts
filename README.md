# Azure-Backup-scripts
Powershell scripts that might be useful when using azure backup


## BreakLeaseAndDeleteSingleMabSnapshots.ps1
When user try to delete the File Share Snapshots that are created and leased by Recovery Service Vault, it is failed due to lease to RSV.
![image](https://user-images.githubusercontent.com/6670688/162994290-7ffa1483-84ea-4f20-99f4-8a23e7551755.png)
https://docs.microsoft.com/en-us/azure/backup/azure-file-share-backup-overview#how-lease-snapshot-works

The snapshots created by RSV shows its Initator as AzureBackup.
In that case, user cannot delete the snapshot manually via Azure Portal.
Below script is for deleting snapshots created and leased by RSV.


### Usage
.\BreakLeaseAndDeleteSingleMabSnaphot.ps1 -ResourceGroupName *RGName* -StorageAccountName *SAName* -FileShareName *FSName* -SubscriptionId *SubsID* -SnapshotName *SnapshotName* -DeleteSnapshot $true

ex) .\BreakLeaseAndDeleteSingleMabSnaphot.ps1 -ResourceGroupName ComputeRG -StorageAccountName shystorageaccount1 -FileShareName fileshareorigin -SubscriptionId d72205c8-690d-45e5-961f-e8ac0d2cb9a3 -SnapshotName 2022-03-31T08:03:26.0000000Z -DeleteSnapshot $true

## BreakLeaseAndDeleteMultipleMabSnapshots.ps
Same purpose and usage as **BreakLeaseAndDeleteSingleMabSnapshots.ps**

### Usage
.\BreakLeaseAndDeleteMultipleMabSnaphot.ps1 -ResourceGroupName *RGName* -StorageAccountName *SAName* -FileShareName fileshareorigin -SubscriptionId *SubsID* -SnapshotName *SnapshotName*, *SnapshotName* -DeleteSnapshot $true

ex) .\BreakLeaseAndDeleteMultipleMabSnaphot.ps1 -ResourceGroupName ComputeRG -StorageAccountName shystorageaccount1 -FileShareName fileshareorigin -SubscriptionId d72205c8-690d-45e5-961f-e8ac0d2cb9a3 -SnapshotName "2022-03-31T08:03:26.0000000Z", "2022-03-31T08:03:44.0000000Z" -DeleteSnapshot $true
