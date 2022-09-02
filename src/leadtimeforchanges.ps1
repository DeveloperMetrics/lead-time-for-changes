Param(
    [string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays
)

#==========================================
#Input processing
$ownerRepoArray = $ownerRepo -split '/'
$owner = $ownerRepoArray[0]
$repo = $ownerRepoArray[1]
Write-Output "Owner/Repo: $owner/$repo"
$workflowsArray = $workflows -split ','
Write-Output "Workflows: $($workflowsArray[0])"
Write-Output "Branch: $branch"
$numberOfDays = $numberOfDays        
Write-Output "Number of days: $numberOfDays"


Write-Output "hello world"
