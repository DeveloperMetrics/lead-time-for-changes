Param(
    [string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays
)

CLS

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


#Get the pull requests

#https://developer.GitHub.com/v3/pulls/#list-pull-requests
#GET /repos/:owner/:repo/pulls
$uri = "https://api.github.com/repos/$owner/$repo/pulls?state=all&head=$branch&per_page=100";
Write-Output $uri
$prsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -ErrorAction Stop

Foreach ($pr in $prsResponse){
            $url2 = "https://api.github.com/repos/$owner/$repo/pulls/$($pr.number)/commits?per_page=100";
            Write-Output $url2
            $prCommitsresponse = Invoke-RestMethod -Uri $url2 -ContentType application/json -Method Get -ErrorAction Stop
            $prCommitsresponse.Length
            # if (string.IsNullOrEmpty(response) == false)
            # {
            #     dynamic buildListObject = JsonConvert.DeserializeObject(response);
            #     list = buildListObject;
            # }
}

#$prsResponse   




Write-Output "hello world"
