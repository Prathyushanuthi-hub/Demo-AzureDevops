param(
    [string]$OrganizationName,
    [string]$PersonalAccessToken
)

# Create header with authentication
$headers = @{
    Authorization = "Bearer $PersonalAccessToken"
    Accept = "application/vnd.github.v3+json"
}

# Base URI for GitHub API
$baseUri = "https://api.github.com"

# Create output directory
$outputPath = "github-details"
New-Item -ItemType Directory -Force -Path $outputPath

# Function to invoke GitHub API
function Invoke-GitHubAPI {
    param($Uri)
    return Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get
}

# Get repositories information
Write-Host "Fetching repository details..."
$repos = Invoke-GitHubAPI "$baseUri/orgs/$OrganizationName/repos?per_page=100"
$repoDetails = $repos | ForEach-Object {
    @{
        Name = $_.name
        Size = $_.size
        Language = $_.language
        Stars = $_.stargazers_count
        Forks = $_.forks_count
        LastUpdated = $_.updated_at
        CloneUrl = $_.clone_url
    }
}
$repoDetails | ConvertTo-Json | Out-File "$outputPath\repositories.json"

# Get organization teams
Write-Host "Fetching team information..."
$teams = Invoke-GitHubAPI "$baseUri/orgs/$OrganizationName/teams"
$teamDetails = $teams | ForEach-Object {
    $teamMembers = Invoke-GitHubAPI "$baseUri/teams/$($_.id)/members"
    @{
        Name = $_.name
        Description = $_.description
        MemberCount = $teamMembers.Count
        Members = $teamMembers.login
    }
}
$teamDetails | ConvertTo-Json -Depth 10 | Out-File "$outputPath\teams.json"

# Get organization members
Write-Host "Fetching organization members..."
$members = Invoke-GitHubAPI "$baseUri/orgs/$OrganizationName/members"
$memberDetails = $members | ForEach-Object {
    $userInfo = Invoke-GitHubAPI "$baseUri/users/$($_.login)"
    @{
        Login = $_.login
        Name = $userInfo.name
        Email = $userInfo.email
        Company = $userInfo.company
        Location = $userInfo.location
    }
}
$memberDetails | ConvertTo-Json | Out-File "$outputPath\members.json"

# Generate summary report
$summary = @{
    RepositoryCount = $repoDetails.Count
    TotalRepoSize = ($repoDetails | Measure-Object -Property Size -Sum).Sum
    TeamCount = $teamDetails.Count
    MemberCount = $memberDetails.Count
    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$summary | ConvertTo-Json | Out-File "$outputPath\summary.json"

Write-Host "GitHub organization details have been exported to the 'github-details' directory."