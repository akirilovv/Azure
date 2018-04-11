#Usage .\ScriptExtensions.ps1 -inputfilepath "C:\results\vmlist.txt" `
  #                                            -outputfilepath "C:\results\Result.txt" `
  #                                            -scriptextensionname "HostNameCheck"
  #                                            -storageaccountname zwtjmpsofia0002storage `
  #                                            -storageaccountkey x33r2xfn2gIyzeVvpAivXmRl4gRosrNElY61NPnsOhwWsQ7TTgEq21UCvIB2jRLZjTEzH3hEIlmJu6TU/+wRqQ== `
  #                                            -storageaccountcontainer scripts `
  #                                            -storageaccountscript dummyscript.ps1 `
#Definining script parameters
function RunScriptExtension(){
Param(
    [string]$inputfilepath ,
    [string]$outputfilepath,
    [string]$scriptextensionname ,
    [string]$storageaccountname ,
    [string]$storageaccountkey  ,
    [string]$storageaccountcontainer,
    [string]$storageaccountscript
)


#A function which will show to the script user the current error and prompt him to continue or not.
function promptonerror($message)
{
    do
    {
        $question=(read-host "$message $($VM.VMname). Do you want to continue with the next VM or exit the script? Press X for exit or C for continue and ENTER").ToLower()
    }
    while($question -ne "x" -and $question -ne "c")

    if($question -eq "x")
    {
        try
        {
            add-content $outputfilepath "$($VM.VMname),$message"
        }
        catch
        {
            throw 'Cannot add content to $outputfilepath. Exiting the program.'
        }
        throw "$message"
    }
    else
    {
        try
        {
            add-content $outputfilepath "$($VM.VMname),$message"
        }
        catch
        {
            throw 'Cannot add content to $outputfilepath. Exiting the program.'
        }
    }
}


#Turns all non-terminating errors to terminating errors, so try/catch statement to catch them all.
$ErrorActionPreference = "Stop"


#checking if the server content file header is properly set. If it is not - exiting the program.
try
{
    $header=(get-content $inputfilepath)[0]
}
catch
{
    throw "Cannot load the server content file properly"
}
if($header -ne "SubscriptionID,ResourceGroup,Location,VMname")
{
    throw "Wrong header. It must be: SubscriptionID,ResourceGroup,Location,VMname"
}


#Importing the server content file. The program will exit if there is a problem.
try
{
    $VMdata=Import-csv $inputfilepath
}
catch
{
    throw "Cannot load the server content file properly."
}


#Loopig through the servers
foreach($VM in $VMdata)
{


    #Setting the current VM Subscription context. If there is a problem the user will be prompted to continue with the next VM or exit the program.
    try
    {
        Set-AzureRmContext -SubscriptionId $VM.SubscriptionID | Out-Null
    }
    catch
    {
        promptonerror "Cannot set subscription context for VM"
        continue
    }


    #Getting current VM object. If tere is a problem the user will be prompted to continue with the next VM or exit the program.
    try
    {
        $serverextension=(Get-AzureRmVM -ResourceGroupName $VM.ResourceGroup -VMName $VM.VMname).extensions.VirtualMachineExtensionType
    }
    catch
    {
        promptonerror "Cannot find VM"
        continue
    }


    #Checking if custom script extension already exist for the current VM. If it doesn't exist it is created for the VM and run the script.
    if(-not($serverextension -match "CustomScriptExtension"))
    {



        #VM Custom Script Extensions are created and run. The user will be prompted to exit or continue to the next VM on error.
        "Creating CustomScriptExtension for VM $($VM.VMname) started at $(Get-Date)"
        try
        {
        $statuscreate=Set-AzureRmVMCustomScriptExtension -ResourceGroupName $VM.ResourceGroup -Location $VM.Location -VMName $VM.VMname -Name $scriptextensionname -StorageAccountName $storageaccountname -StorageAccountKey $storageaccountkey  -FileName $storageaccountscript -ContainerName $storageaccountcontainer -Run $storageaccountscript
        }
        catch
        {


            #Custom script extension should be removed even after they were failed to be assigned properly.
            try
            {
                $statusremove=Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $VM.ResourceGroup -VMName $VM.VMname -Name $scriptextensionname -Force
            }
            catch
            {
                "Cannot remove custom script extension for VM $($VM.VMname) after custom script extension creation failure"
                add-content $outputfilepath "$($VM.VMname),extensions fail to remove properly after custom script extension creation failure"
            }
            if($statusremove.StatusCode -eq "OK")
            {
                "CustomScriptExtension for VM $($VM.VMname) succesfully removed after custom script extension creation failure at $(Get-Date)"
            }
            else
            {
                try
                {
                    add-content $outputfilepath "$($VM.VMname),extensions fail to remove properly after custom script extension creation failure"
                }
                catch
                {
                    throw 'Cannot add content to $outputfilepath. Exiting the program.'
                }
            }
            promptonerror "Cannot add or run custom script extensions on VM"
            continue
        }


        #Checking the status of script extension execution. If it is ok the result is extracted to the output file.
        if($statuscreate.StatusCode -eq "OK")
        {
            "CustomScriptExtension for VM $($VM.VMname) has been created and run successfully at $(Get-Date)"
            try
            {
                $VMResult=(Get-AzureRmVMDiagnosticsExtension -ResourceGroupName $VM.ResourceGroup -VMName $VM.VMname -Name $scriptextensionname -Status).SubStatuses[0].Message
            }
            catch
            {
                promptonerror "Cannot get VM Diagnostic extensions on VM"
                continue
            }
            try
            {
                add-content $outputfilepath "$($VM.VMname),$VMResult"
            }
            catch
            {
                throw 'Cannot add content to $outputfilepath. Exiting the program.'
            }

        }
        else
        {
            "Running CustomScriptExtension for VM $($VM.VMname) failed at $(Get-Date)"
            try
            {
                add-content $outputfilepath "$($VM.VMname),running Custom Script extension failed"
            }
            catch
            {
                throw 'Cannot add content to $outputfilepath. Exiting the program.'
            }
        }


        #Removing custom script extension. The user will be prompted to exit or continue to the next VM on error.
        "Removing CustomScriptExtension for VM $($VM.VMname) started at $(Get-Date)"
        try
        {
            $statusremove=Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $VM.ResourceGroup -VMName $VM.VMname -Name $scriptextensionname -Force
        }
        catch
        {
            promptonerror "Cannot remove custom script extension for VM"
            continue
        }
        if($statusremove.StatusCode -eq "OK")
        {
            "CustomScriptExtension for VM $($VM.VMname) succesfully removed at $(Get-Date)"
        }
        else
        {
            try
            {
                "CustomScriptExtension for VM $($VM.VMname) fail to remove properly at $(Get-Date)"
                add-content $outputfilepath "$($VM.VMname),extensions fail to remove properly"
            }
            catch
            {
                throw 'Cannot add content to $outputfilepath. Exiting the program.'
            }
        }
    }
    else
    {
        "CustomScriptExtension for VM $($VM.VMname) already exist at $(Get-Date)"
        try
        {
            add-content $outputfilepath "$($VM.VMname),scirpt extension existed"
        }
        catch
        {
            throw 'Cannot add content to $outputfilepath. Exiting the program.'
        }
    }
}
}


RunScriptExtension -inputfilepath "C:\tmp\vmlistpoc.csv" `
                                              -outputfilepath "C:\results\SQLResult.txt" `
                                              -scriptextensionname "SQLServerCheck1" `
                                              -storageaccountname sofiacloudrcstorage01 `
                                              -storageaccountkey JbrKOKF3P3hR95zbxkKuot6GQ43LywOfQ5ye9Op0NAcvNq9hwBwRiSwJw5lu0Cng70j9P4jKOCdDSuZvWNFpxg== `
                                              -storageaccountcontainer scripts `
                                              -storageaccountscript SQLCheck.ps1 `
