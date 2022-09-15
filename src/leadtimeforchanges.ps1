#Parameters for the top level  leadtimeforchanges.ps1 PowerShell script
Param(
    [string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays,
    [string] $patToken = "",
    [string] $actionsToken = ""#,
    #[string] $gitHubAppToken 
)

#The main function
function Main ([string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays,
    [string] $patToken,
    [string] $actionsToken#,
    #[string] $gitHubAppToken 
    )
{

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

    #==========================================
    # Get authorization headers
    $authHeader = GetAuthHeader($patToken, $actionsToken)

    #Get pull requests from the repo 
    #https://developer.GitHub.com/v3/pulls/#list-pull-requests
    $uri = "https://api.github.com/repos/$owner/$repo/pulls?state=all&head=$branch&per_page=100";
    if (!$authHeader)
    {
        #No authentication
        Write-Output "No authentication"
        $workflowsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }
    else
    {
        #there is authentication
        if (![string]::IsNullOrEmpty($patToken))
        {
            Write-Output "Authentication detected: PAT TOKEN"  
        }      
        elseif (![string]::IsNullOrEmpty($actionsToken))
        {
            Write-Output "Authentication detected: GITHUB TOKEN"  
        }

        $prsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus" 
    }
    if ($HTTPStatus -eq "404")
    {
        Write-Output "Repo is not found or you do not have access"
        break
    }  
    
    Foreach ($pr in $prsResponse){
                $url2 = "https://api.github.com/repos/$owner/$repo/pulls/$($pr.number)/commits?per_page=100";
                Write-Output $url2
                $prCommitsresponse = Invoke-RestMethod -Uri $url2 -ContentType application/json -Method Get -ErrorAction Stop
                if ($prCommitsresponse.Length -ge 1)
                {
                    $startDate = $prCommitsresponse[0].committer.date
                }
                if ($pr.Status -eq "closed" -and $pr.merged_at -ne $null)
                {
                    $prTimeDuration = New-TimeSpan –Start $startDate –End $pr.merged_at
                }
                break
    }

    Write-Output "PR time duration $prTimeDuration"
}


#Generate the authorization header for the PowerShell call to the GitHub API
#warning: PowerShell has really wacky return semantics - all output is captured, and returned
#reference: https://stackoverflow.com/questions/10286164/function-return-value-in-powershell
function GetAuthHeader ([string] $patToken, [string] $actionsToken) 
{
    #Clean the string - without this the PAT TOKEN doesn't process
    $patToken = $patToken.Trim()

    if (![string]::IsNullOrEmpty($patToken))
    {
        $base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$patToken"))
        $authHeader = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    }
    elseif (![string]::IsNullOrEmpty($actionsToken))
    {
        $authHeader = @{Authorization=("Bearer {0}" -f $base64AuthInfo)}
    }
    else
    {
        $base64AuthInfo = $null
        $authHeader = $null
    }

    return $authHeader
}

main -ownerRepo $ownerRepo -workflows $workflows -branch $branch -numberOfDays $numberOfDays -patToken $patToken -actionsToken $actionsToken