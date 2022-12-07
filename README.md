# Lead Time for Changes
A GitHub Action to roughly calculate DORA lead time for changes This is not meant to be an exhaustive calculation, but we are able to approximate fairly close for most  of workflows. Why? Our [insights](https://samlearnsazure.blog/2022/08/23/my-insights-about-measuring-dora-devops-metrics-and-how-you-can-learn-from-my-mistakes/) indicated that many applications don't need exhaustive DORA analysis - a high level, order of magnitude result is accurate for most workloads. 

[![CI](https://github.com/samsmithnz/lead-time-for-changes/actions/workflows/workflow.yml/badge.svg)](https://github.com/samsmithnz/lead-time-for-changes/actions/workflows/workflow.yml)
[![Current Release](https://img.shields.io/github/release/samsmithnz/lead-time-for-changes/all.svg)](https://github.com/samsmithnz/lead-time-for-changes/releases)

## Current Calculation
- Get the last 100 closed Pull Requests
- For each Pull Request, if it was merged in the last 30 days, calculate the time the PR was open, taking the merge time and either the first or last commit time (specified as a parameter), aggregating for an overall PR duration average.
- For each workflow, if it started in the last 30 days and was run on the target branch, calculate the workflow run time, aggregating for an overall workflow duration average
- Add the Pull Request and workflow durations to output the lead time for changes result.
- Then translate this result to friendly n days/weeks/months.

## Current Limitations
- Only looks at the last 100 closed Pull Requests and 100 completed workflows. If number of Pull Requests and/or deployments to the target branch is low, this will skew the result.

## Open questions

## Inputs
- `workflows`: required, string, The name of the workflows to process. Multiple workflows can be separated by `,` 
- `owner-repo`: optional, string, defaults to the repo where the action runs. Can target another owner or org and repo. e.g. `'samsmithnz/DevOpsMetrics'`, but will require authenication (see below)
- `default-branch`: optional, string, defaults to `main` 
- `number-of-days`: optional, integer, defaults to `30` (days)
- commit-counting-method: #optional, defaults to 'last'. Accepts two values, 'last' - to start timing from the last commit of a PR, and 'first' to start timing from the first commit of a PR
- `pat-token`: optional, string, defaults to ''. Can be set with GitHub PAT token. Ensure that `Read access to actions and metadata` permission is set. This is a secret, never directly add this into the actions workflow, use a secret.
- `actions-token`: optional, string, defaults to ''. Can be set with `${{ secrets.GITHUB_TOKEN }}` in the action
- `app-id`: optional, string, defaults to '', application id of the registered GitHub app
- `app-install-id`: optional, string, defaults to '', id of the installed instance of the GitHub app
- `app-private-key` optional, string, defaults to '', private key which has been generated for the installed instance of the GitHub app. Must be provided without leading `'-----BEGIN RSA PRIVATE KEY----- '` and trailing `' -----END RSA PRIVATE KEY-----'`.

To test the current repo (same as where the action runs)
```
- uses: samsmithnz/deployment-frequency@main
  with:
    workflows: 'CI'
```

To test another repo, with all arguments
```
- name: Test another repo
  uses: samsmithnz/deployment-frequency@main
  with:
    workflows: 'CI/CD'
    owner-repo: 'samsmithnz/DevOpsMetrics'
    default-branch: 'main'
    number-of-days: 30
```

To use a PAT token to access another (potentially private) repo:
```
- name: Test elite repo with PAT Token
  uses: samsmithnz/deployment-frequency@main
  with:
    workflows: 'CI/CD'
    owner-repo: 'samsmithnz/SamsFeatureFlags'
    pat-token: "${{ secrets.PATTOKEN }}"
```

Use the built in Actions GitHub Token to retrieve the metrix 
```
- name: Test this repo with GitHub Token
  uses: samsmithnz/deployment-frequency@main
  with:
    workflows: 'CI'
    actions-token: "${{ secrets.GITHUB_TOKEN }}"
```

Gather the metric from another repository using GitHub App authentication method:
```
- name: Test another repo with GitHub App
  uses: samsmithnz/deployment-frequency@main
  with:
    workflows: 'CI'
    owner-repo: 'samsmithnz/some-other-repo'
    app-id: "${{ secrets.APPID }}"
    app-install-id: "${{ secrets.APPINSTALLID }}"
    app-private-key: "${{ secrets.APPPRIVATEKEY }}"
```

# Setup
Permissions: Read access to actions, metadata, and pull requests

# Output

Current output shows the inputs, authenication method, rate limit consumption, and then the actual lead time for changes
```
Owner/Repo: samsmithnz/SamsFeatureFlags
Workflows: Feature Flags CI/CD
Branch: main
Number of days: 30
Commit counting method 'last' being used
Authentication detected: PAT TOKEN
PR average time duration 5.4612962962963
Workflow average time duration 0.30224537037037
Rate limit consumption: 242 / 5000
Lead time for changes average over last 30 days, is 5.76 hours, with a DORA rating of 'Elite'
```

In the job summary, we show a badge with details:

 ---
 ![Lead time for changes](https://img.shields.io/badge/frequency-5.61%20hours-green?logo=github&label=Lead%20time%20for%20changes)<br>
 **Definition:** For the primary application or service, how long does it take to go from code committed to code successfully running in production.<br>
 **Results:** Lead time for changes is **5.61 hours** with a **Elite** rating, over the last **30 days**.<br>
 **Details**:
 - Repository: samsmithnz/deployment-frequency using main branch
 - Workflow(s) used: CI
 ---
