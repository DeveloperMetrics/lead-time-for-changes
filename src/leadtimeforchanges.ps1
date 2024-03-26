#Parameters for the top level  leadtimeforchanges.ps1 PowerShell script
Param(
    [string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays,
    [string] $commitCountingMethod = "last",
    [string] $patToken = "",
    [string] $actionsToken = "",
    [string] $appId = "",
    [string] $appInstallationId = "",
    [string] $appPrivateKey = ""
)

#The main function
function Main ([string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays,
    [string] $commitCountingMethod,
    [string] $patToken = "",
    [string] $actionsToken = "",
    [string] $appId = "",
    [string] $appInstallationId = "",
    [string] $appPrivateKey = "")
{

    #==========================================
    #Input processing
    $ownerRepoArray = $ownerRepo -split '/'
    $owner = $ownerRepoArray[0]
    $repo = $ownerRepoArray[1]
    $workflowsArray = $workflows -split ','
    $numberOfDays = $numberOfDays        
    if ($commitCountingMethod -eq "")
    {
        $commitCountingMethod = "last"
    }
    Write-Host "Owner/Repo: $owner/$repo"
    Write-Host "Number of days: $numberOfDays"
    Write-Host "Workflows: $($workflowsArray[0])"
    Write-Host "Branch: $branch"
    Write-Host "Commit counting method '$commitCountingMethod' being used"

    #==========================================
    # Get authorization headers
    $authHeader = GetAuthHeader $patToken $actionsToken $appId $appInstallationId $appPrivateKey

    #Get pull requests from the repo 
    #https://developer.GitHub.com/v3/pulls/#list-pull-requests
    $uri = "https://api.github.com/repos/$owner/$repo/pulls?state=all&head=$branch&per_page=100&state=closed";
    if (!$authHeader)
    {
        #No authentication
        $prsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }
    else
    {
        $prsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus" 
    }
    if ($HTTPStatus -eq "404")
    {
        Write-Output "Repo is not found or you do not have access"
        break
    }  

    $prCounter = 0
    $totalPRHours = 0
    Foreach ($pr in $prsResponse){

        $mergedAt = $pr.merged_at
        if ($mergedAt -ne $null -and $pr.merged_at -gt (Get-Date).AddDays(-$numberOfDays))
        {
            $prCounter++
            $url2 = "https://api.github.com/repos/$owner/$repo/pulls/$($pr.number)/commits?per_page=100";
            if (!$authHeader)
            {
                #No authentication
                $prCommitsresponse = Invoke-RestMethod -Uri $url2 -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
            }
            else
            {
                $prCommitsresponse = Invoke-RestMethod -Uri $url2 -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus" 
            }
            if ($prCommitsresponse.Length -ge 1)
            {
                if ($commitCountingMethod -eq "last")
                {
                    $startDate = $prCommitsresponse[$prCommitsresponse.Length-1].commit.committer.date
                }
                elseif ($commitCountingMethod -eq "first")
                {
                    $startDate = $prCommitsresponse[0].commit.committer.date
                }
                else
                {
                    Write-Output "Commit counting method '$commitCountingMethod' is unknown. Expecting 'first' or 'last'"
                }
            }
        
            if ($startDate -ne $null)
            {
                $prTimeDuration = New-TimeSpan –Start $startDate –End $mergedAt
                $totalPRHours += $prTimeDuration.TotalHours
                #Write-Host "$($pr.number) time duration in hours: $($prTimeDuration.TotalHours)"
            }
        }
    }

    #==========================================
    #Get workflow definitions from github
    $uri3 = "https://api.github.com/repos/$owner/$repo/actions/workflows"
    if (!$authHeader) #No authentication
    {
        $workflowsResponse = Invoke-RestMethod -Uri $uri3 -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }
    else  #there is authentication
    {
        $workflowsResponse = Invoke-RestMethod -Uri $uri3 -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus" 
    }
    if ($HTTPStatus -eq "404")
    {
        Write-Output "Repo is not found or you do not have access"
        break
    }  

    #Extract workflow ids from the definitions, using the array of names. Number of Ids should == number of workflow names
    $workflowIds = [System.Collections.ArrayList]@()
    $workflowNames = [System.Collections.ArrayList]@()
    Foreach ($workflow in $workflowsResponse.workflows){

        Foreach ($arrayItem in $workflowsArray){
            if ($workflow.name -eq $arrayItem)
            {
                #This looks odd: but assigning to a (throwaway) variable stops the index of the arraylist being output to the console. Using an arraylist over an array has advantages making this worth it for here
                if (!$workflowIds.Contains($workflow.id))
                {
                    $result = $workflowIds.Add($workflow.id)
                }
                if (!$workflowNames.Contains($workflow.name))
                {
                    $result = $workflowNames.Add($workflow.name)
                }
            }
        }
    }

    #==========================================
    #Filter out workflows that were successful. Measure the number by date/day. Aggegate workflows together
    $workflowList = @()
    
    #For each workflow id, get the last 100 workflows from github
    Foreach ($workflowId in $workflowIds){
        #set workflow counters    
        $workflowCounter = 0
        $totalWorkflowHours = 0
        
        #Get workflow definitions from github
        $uri4 = "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/runs?per_page=100&status=completed"
        if (!$authHeader)
        {
            $workflowRunsResponse = Invoke-RestMethod -Uri $uri4 -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
        }
        else
        {
            $workflowRunsResponse = Invoke-RestMethod -Uri $uri4 -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"      
        }

        Foreach ($run in $workflowRunsResponse.workflow_runs){
            #Count workflows that are completed, on the target branch, and were created within the day range we are looking at
            if ($run.head_branch -eq $branch -and $run.created_at -gt (Get-Date).AddDays(-$numberOfDays))
            {
                #Write-Host "Adding item with status $($run.status), branch $($run.head_branch), created at $($run.created_at), compared to $((Get-Date).AddDays(-$numberOfDays))"
                $workflowCounter++       
                #calculate the workflow duration            
                $workflowDuration = New-TimeSpan –Start $run.created_at –End $run.updated_at
                $totalworkflowHours += $workflowDuration.TotalHours    
            }
        }
        
        #Save the workflow duration working per workflow
        if ($workflowCounter -gt 0)
        {             
            $workflowList += New-Object PSObject -Property @{totalworkflowHours=$totalworkflowHours;workflowCounter=$workflowCounter}                
        }
    }

    #==========================================
    #Prevent divide by zero errors
    if ($prCounter -eq 0)
    {   
        $prCounter = 1
    }
    $totalAverageworkflowHours = 0
    Foreach ($workflowItem in $workflowList){
        if ($workflowItem.workflowCounter -eq 0)
        {
            $workflowItem.workflowCounter = 1
        }
        $totalAverageworkflowHours += $workflowItem.totalworkflowHours / $workflowItem.workflowCounter
    }
    
    #Aggregate the PR and workflow processing times to calculate the average number of hours 
    Write-Host "PR average time duration $($totalPRHours / $prCounter)"
    Write-Host "Workflow average time duration $($totalAverageworkflowHours)"
    $leadTimeForChangesInHours = ($totalPRHours / $prCounter) + ($totalAverageworkflowHours)
    Write-Host "Lead time for changes in hours: $leadTimeForChangesInHours"

    #==========================================
    #Show current rate limit
    $uri5 = "https://api.github.com/rate_limit"
    if (!$authHeader)
    {
        $rateLimitResponse = Invoke-RestMethod -Uri $uri5 -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }
    else
    {
        $rateLimitResponse = Invoke-RestMethod -Uri $uri5 -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }    
    Write-Host "Rate limit consumption: $($rateLimitResponse.rate.used) / $($rateLimitResponse.rate.limit)"

    #==========================================
    #output result
    $dailyDeployment = 24
    $weeklyDeployment = 24 * 7
    $monthlyDeployment = 24 * 30
    $everySixMonthsDeployment = 24 * 30 * 6 #Every 6 months

    #Calculate rating, metric and unit  
    if ($leadTimeForChangesInHours -le 0)
    {
        $rating = "None"
        $color = "lightgrey"
        $displayMetric = 0
        $displayUnit = "hours"
    }
    elseif ($leadTimeForChangesInHours -lt 1) 
    {
        $rating = "Elite"
        $color = "brightgreen"
        $displayMetric = [math]::Round($leadTimeForChangesInHours * 60, 2)
        $displayUnit = "minutes"
    }
    elseif ($leadTimeForChangesInHours -le $dailyDeployment) 
    {
        $rating = "Elite"
        $color = "brightgreen"
        $displayMetric = [math]::Round($leadTimeForChangesInHours, 2)
        $displayUnit = "hours"
    }
    elseif ($leadTimeForChangesInHours -gt $dailyDeployment -and $leadTimeForChangesInHours -le $weeklyDeployment)
    {
        $rating = "High"
        $color = "green"
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24, 2)
        $displayUnit = "days"
    }
    elseif ($leadTimeForChangesInHours -gt $weeklyDeployment -and $leadTimeForChangesInHours -le $monthlyDeployment)
    {
        $rating = "High"
        $color = "green"
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24, 2)
        $displayUnit = "days"
    }
    elseif ($leadTimeForChangesInHours -gt $monthlyDeployment -and $leadTimeForChangesInHours -le $everySixMonthsDeployment)
    {
        $rating = "Medium"
        $color = "yellow"
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24 / 30, 2)
        $displayUnit = "months"
    }
    elseif ($leadTimeForChangesInHours -gt $everySixMonthsDeployment)
    {
        $rating = "Low"
        $color = "red"
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24 / 30, 2)
        $displayUnit = "months"
    }
    if ($leadTimeForChangesInHours -gt 0 -and $numberOfDays -gt 0)
    {
        Write-Host "Lead time for changes average over last $numberOfDays days, is $displayMetric $displayUnit, with a DORA rating of '$rating'"
        return GetFormattedMarkdown -workflowNames $workflowNames -displayMetric $displayMetric -displayUnit $displayUnit -repo $ownerRepo -branch $branch -numberOfDays $numberOfDays -color $color -rating $rating
    }
    else
    {
        Write-Host "No lead time for changes to display for this workflow and time period"
        return GetFormattedMarkdownForNoResult -workflows $workflows -numberOfDays $numberOfDays
    }
}


#Generate the authorization header for the PowerShell call to the GitHub API
#warning: PowerShell has really wacky return semantics - all output is captured, and returned
#reference: https://stackoverflow.com/questions/10286164/function-return-value-in-powershell
function GetAuthHeader ([string] $patToken, [string] $actionsToken, [string] $appId, [string] $appInstallationId, [string] $appPrivateKey) 
{
    #Clean the string - without this the PAT TOKEN doesn't process
    $patToken = $patToken.Trim()
    #Write-Host  $appId
    #Write-Host "pattoken: $patToken"
    #Write-Host "app id is something: $(![string]::IsNullOrEmpty($appId))"
    #Write-Host "patToken is something: $(![string]::IsNullOrEmpty($patToken))"
    if (![string]::IsNullOrEmpty($patToken))
    {
        Write-Host "Authentication detected: PAT TOKEN"
        $base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$patToken"))
        $authHeader = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
    }
    elseif (![string]::IsNullOrEmpty($actionsToken))
    {
        Write-Host "Authentication detected: GITHUB TOKEN"  
        $authHeader = @{Authorization=("Bearer {0}" -f $actionsToken)}
    }
    elseif (![string]::IsNullOrEmpty($appId)) # GitHup App auth
    {
        Write-Host "Authentication detected: GITHUB APP TOKEN"  
        $token = Get-JwtToken $appId $appInstallationId $appPrivateKey        
        $authHeader = @{Authorization=("token {0}" -f $token)}
    }    
    else
    {
        Write-Host "No authentication detected" 
        $base64AuthInfo = $null
        $authHeader = $null
    }

    return $authHeader
}

function ConvertTo-Base64UrlString(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$in) 
{
    if ($in -is [string]) {
        return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($in)) -replace '\+','-' -replace '/','_' -replace '='
    }
    elseif ($in -is [byte[]]) {
        return [Convert]::ToBase64String($in) -replace '\+','-' -replace '/','_' -replace '='
    }
    else {
        throw "GitHub App authenication error: ConvertTo-Base64UrlString requires string or byte array input, received $($in.GetType())"
    }
}

function Get-JwtToken([string] $appId, [string] $appInstallationId, [string] $appPrivateKey)
{
    # Write-Host "appId: $appId"
    $now = (Get-Date).ToUniversalTime()
    $createDate = [Math]::Floor([decimal](Get-Date($now) -UFormat "%s"))
    $expiryDate = [Math]::Floor([decimal](Get-Date($now.AddMinutes(4)) -UFormat "%s"))
    $rawclaims = [Ordered]@{
        iat = [int]$createDate
        exp = [int]$expiryDate
        iss = $appId
    } | ConvertTo-Json
    # Write-Host "expiryDate: $expiryDate"
    # Write-Host "rawclaims: $rawclaims"

    $Header = [Ordered]@{
        alg = "RS256"
        typ = "JWT"
    } | ConvertTo-Json
    # Write-Host "Header: $Header"
    $base64Header = ConvertTo-Base64UrlString $Header
    # Write-Host "base64Header: $base64Header"
    $base64Payload = ConvertTo-Base64UrlString $rawclaims
    # Write-Host "base64Payload: $base64Payload"

    $jwt = $base64Header + '.' + $base64Payload
    $toSign = [System.Text.Encoding]::UTF8.GetBytes($jwt)

    $rsa = [System.Security.Cryptography.RSA]::Create();    
    # https://stackoverflow.com/a/70132607 lead to the right import
    $rsa.ImportRSAPrivateKey([System.Convert]::FromBase64String($appPrivateKey), [ref] $null);

    try { $sig = ConvertTo-Base64UrlString $rsa.SignData($toSign,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
    catch { throw New-Object System.Exception -ArgumentList ("GitHub App authenication error: Signing with SHA256 and Pkcs1 padding failed using private key $($rsa): $_", $_.Exception) }
    $jwt = $jwt + '.' + $sig
    # send headers
    $uri = "https://api.github.com/app/installations/$appInstallationId/access_tokens"
    $jwtHeader = @{
        Accept = "application/vnd.github+json"
        Authorization = "Bearer $jwt"
    }
    $tokenResponse = Invoke-RestMethod -Uri $uri -Headers $jwtHeader -Method Post -ErrorAction Stop
    # Write-Host $tokenResponse.token
    return $tokenResponse.token
}

# Format output for deployment frequency in markdown
function GetFormattedMarkdown([array] $workflowNames, [string] $rating, [string] $displayMetric, [string] $displayUnit, [string] $repo, [string] $branch, [string] $numberOfDays, [string] $numberOfUniqueDates, [string] $color)
{
    $encodedString = [uri]::EscapeUriString($displayMetric + " " + $displayUnit)
    #double newline to start the line helps with formatting in GitHub logs
    $markdown = "`n`n![Lead time for changes](https://img.shields.io/badge/frequency-" + $encodedString + "-" + $color + "?logo=github&label=Lead%20time%20for%20changes)`n" +
        "**Definition:** For the primary application or service, how long does it take to go from code committed to code successfully running in production.`n" +
        "**Results:** Lead time for changes is **$displayMetric $displayUnit** with a **$rating** rating, over the last **$numberOfDays days**.`n" + 
        "**Details**:`n" + 
        "- Repository: $repo using $branch branch`n" + 
        "- Workflow(s) used: $($workflowNames -join ", ")`n" +
        "---"
    return $markdown
}

function GetFormattedMarkdownForNoResult([string] $workflows, [string] $numberOfDays)
{
    #double newline to start the line helps with formatting in GitHub logs
    $markdown = "`n`n![Lead time for changes](https://img.shields.io/badge/frequency-none-lightgrey?logo=github&label=Lead%20time%20for%20changes)`n`n" +
        "No data to display for $ownerRepo over the last $numberOfDays days`n`n" + 
        "---"
    return $markdown
}

main -ownerRepo $ownerRepo -workflows $workflows -branch $branch -numberOfDays $numberOfDays -commitCountingMethod $commitCountingMethod  -patToken $patToken -actionsToken $actionsToken -appId $appId -appInstallationId $appInstallationId -appPrivateKey $appPrivateKey
