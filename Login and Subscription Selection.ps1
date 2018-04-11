<#
.NAME
	Login and Subscription Selection.ps1

.DESCRIPTION
	This script initializes login to Azure and prompts for a subscription.

.NOTES
    AUTHOR: Andrew Delosky
    LASTEDIT: 11/13/17

#>

###########################################################################################
#### VARIABLES
###########################################################################################


###########################################################################################
#### SECTION 1: Log into Azure
###########################################################################################
    Write-Host "Checking For Active Session" -foregroundcolor Yellow;
    
    Try {Get-AzureRMSubscription | Out-Null}
    Catch {
    Write-Host "`nNo Active Session Found. Please log into Azure now." -foregroundcolor Green;
    Login-AzureRmAccount
    }
    
    #Create Subscription List
        $SubscriptionList = Get-AzureRmSubscription

        $SubscriptionList | Sort-Object @{Expression = 'SubscriptionName'} | ForEach -Begin {$SubscriptionNumber = 0;$subscriptionResults = $null} -Process {

            $SubscriptionNumber ++

            $SubscriptionProperties = @{'SubscriptionNumber'=$SubscriptionNumber;
                'SubscriptionName'=$_.Name
                'SubscriptionID'=$_.SubscriptionId
                }
            $PSObjectSubscription = New-Object -TypeName PSObject -Property $SubscriptionProperties

            $subscriptionResults += @($PSObjectSubscription)
        }

        Write-Host "`nActive Subscriptions:" -ForegroundColor Green
      
        $subscriptionResults | FT @{label="Subscription`nNumber";Expression={($_.subscriptionnumber)};align='center'},@{label="`nSubscriptionName";Expression={($_.subscriptionname)}},
    @{label="`nSubscriptionID";Expression={($_.subscriptionID)}}

    #User Selects Subscription
        Do {
            $SubscriptionSelection = Read-Host 'Please enter a subscription number and press enter'
        }
        Until ($SubscriptionSelection -in 1..$SubscriptionNumber)

        $selectedSubscription = $subscriptionResults | Where-Object {$_.subscriptionnumber -eq $SubscriptionSelection}

    #Set selected subscription to active
        Try{
            Write-Host "`nSetting $($selectedSubscription.subscriptionName) as the active subscription..." -ForegroundColor Yellow
            Select-AzureRMSubscription -SubscriptionId $selectedSubscription.SubscriptionID | Out-Null
            Write-Host "`n$($selectedSubscription.subscriptionName) is set as the active subscription." -ForegroundColor Green
        }

        Catch{
            Write-Host "`nError occured while attempting to set the Active Subscription" -ForegroundColor Red
            #Return the error message
            Return $_
        }

        Finally{
            Clear-Variable -Name selectedSubscription -ErrorAction SilentlyContinue
            Clear-Variable -Name subscriptionResults -ErrorAction SilentlyContinue
        }
