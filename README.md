# lead-time-for-changes
A GitHub Action to roughly calculate DORA lead time for changes This is not meant to be an exhaustive calculation, but we are able to approximate fairly close for most  of workflows. Why? Our [insights](https://samlearnsazure.blog/2022/08/23/my-insights-about-measuring-dora-devops-metrics-and-how-you-can-learn-from-my-mistakes/) indicated that many applications don't need exhaustive DORA analysis - a high level, order of magnitude result is accurate for most workloads. 

[![CI](https://github.com/samsmithnz/lead-time-for-changes/actions/workflows/workflow.yml/badge.svg)](https://github.com/samsmithnz/lead-time-for-changes/actions/workflows/workflow.yml)
[![Current Release](https://img.shields.io/github/release/samsmithnz/lead-time-for-changes/all.svg)](https://github.com/samsmithnz/lead-time-for-changes/releases)

## Current Calculation

## Current Limitations

## Open questions

## Inputs
- `workflows`: required, string, The name of the workflows to process. Multiple workflows can be separated by `,` (note that currently only the first workflow in the string is processed)
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


Permissions: Read access to actions, metadata, and pull requests
