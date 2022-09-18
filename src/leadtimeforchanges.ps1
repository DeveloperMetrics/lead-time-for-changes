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
    Write-Output "Owner/Repo: $owner/$repo"
    $workflowsArray = $workflows -split ','
    Write-Output "Workflows: $($workflowsArray[0])"
    Write-Output "Branch: $branch"
    $numberOfDays = $numberOfDays        
    Write-Output "Number of days: $numberOfDays"
    if ($commitCountingMethod -eq "")
    {
        $commitCountingMethod = "last"
    }
    Write-Output "Commit counting method '$commitCountingMethod' being used"

    #==========================================
    # Get authorization headers
    $authHeader = GetAuthHeader($patToken, $actionsToken)

    #Get pull requests from the repo 
    #https://developer.GitHub.com/v3/pulls/#list-pull-requests
    $uri = "https://api.github.com/repos/$owner/$repo/pulls?state=all&head=$branch&per_page=100";
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
    $totalHours = 0
    Foreach ($pr in $prsResponse){

        $mergedAt = $pr.merged_at
        if ($pr.state -eq "closed" -and $mergedAt -ne $null -and $pr.merged_at -gt (Get-Date).AddDays(-$numberOfDays))
        {
            $prCounter++
            $url2 = "https://api.github.com/repos/$owner/$repo/pulls/$($pr.number)/commits?per_page=100";
            $prCommitsresponse = Invoke-RestMethod -Uri $url2 -ContentType application/json -Method Get -ErrorAction Stop
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
        
            $prTimeDuration = New-TimeSpan –Start $startDate –End $mergedAt
            $totalHours += $prTimeDuration.TotalHours
            #Write-Output "$($pr.number) time duration in hours: $($prTimeDuration.TotalHours)"
        }
    }
    $leadTimeForChangesInHours  = $totalHours / $prCounter

    #==========================================
    #Show current rate limit
    $uri3 = "https://api.github.com/rate_limit"
    if (!$authHeader)
    {
        $rateLimitResponse = Invoke-RestMethod -Uri $uri3 -ContentType application/json -Method Get -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }
    else
    {
        $rateLimitResponse = Invoke-RestMethod -Uri $uri3 -ContentType application/json -Method Get -Headers @{Authorization=($authHeader["Authorization"])} -SkipHttpErrorCheck -StatusCodeVariable "HTTPStatus"
    }    
    Write-Output "Rate limit consumption: $($rateLimitResponse.rate.used) / $($rateLimitResponse.rate.limit)"

    #==========================================
    #output result
    $dailyDeployment = 1
    $weeklyDeployment = 1 / 7
    $monthlyDeployment = 1 / 30
    $everySixMonthsDeployment = 1 / (6 * 30) #//Every 6 months
    $yearlyDeployment = 1 / 365

    #Calculate rating 
    $rating = ""
    if ($leadTimeForChangesInHours -le 0)
    {
        $rating = "None"
    }
    elseif ($leadTimeForChangesInHours -ge $dailyDeployment)
    {
        $rating = "Elite"
    }
    elseif ($leadTimeForChangesInHours -le $dailyDeployment -and $leadTimeForChangesInHours -ge $weeklyDeployment)
    {
        $rating = "High"
    }
    elseif (leadTimeForChangesInHours -le $weeklyDeployment -and $leadTimeForChangesInHours -ge $everySixMonthsDeployment)
    {
        $rating = "Medium"
    }
    elseif ($leadTimeForChangesInHours -le $everySixMonthsDeployment)
    {
        $rating = "Low"
    }

    #Calculate metric and unit
    if ($leadTimeForChangesInHours -gt $dailyDeployment) 
    {
        $displayMetric = [math]::Round($leadTimeForChangesInHours,2)
        $displayUnit = "hours"
    }
    elseif ($leadTimeForChangesInHours -le $dailyDeployment -and $leadTimeForChangesInHours -ge $weeklyDeployment)
    {
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24, 2)
        $displayUnit = "days"
    }
    elseif ($leadTimeForChangesInHours -lt $weeklyDeployment -and $leadTimeForChangesInHours -ge $monthlyDeployment)
    {
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24,2)
        $displayUnit = "days"
    }
    elseif ($leadTimeForChangesInHours -lt $monthlyDeployment -and $leadTimeForChangesInHours -gt $yearlyDeployment)
    {
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 24 / 30,2)
        $displayUnit = "months"
    }
    elseif ($leadTimeForChangesInHours -le $yearlyDeployment)
    {
        $displayMetric = [math]::Round($leadTimeForChangesInHours / 365,2)
        $displayUnit = "years"
    }
    Write-Output "PR average time duration $leadTimeForChangesInHours"
    if ($leadTimeForChangesInHours -gt 0 -and $numberOfDays -gt 0)
    {
        Write-Output "Lead time for changes over last $numberOfDays days, is $displayMetric $displayUnit, with a DORA rating of '$rating'"
    }
    else
    {
        Write-Output "Lead time for changes: no data to display for this workflow and time period"
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
        $authHeader = @{Authorization=("Bearer {0}" -f $base64AuthInfo)}
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

main -ownerRepo $ownerRepo -workflows $workflows -branch $branch -numberOfDays $numberOfDays -commitCountingMethod $commitCountingMethod  -patToken $patToken -actionsToken $actionsToken -appId $appId -appInstallationId $appInstallationId -appPrivateKey $appPrivateKey
