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
    try {
        $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        Write-Warning "Error accessing GitHub API at $Uri"
        Write-Warning "Status Code: $($_.Exception.Response.StatusCode.value__)"
        Write-Warning "Status Description: $($_.Exception.Response.StatusDescription)"
        
        # For rate limit issues, provide more information
        if ($_.Exception.Response.StatusCode.value__ -eq 403) {
            $rateLimit = $_.Exception.Response.Headers["X-RateLimit-Limit"]
            $rateLimitRemaining = $_.Exception.Response.Headers["X-RateLimit-Remaining"]
            $rateLimitReset = $_.Exception.Response.Headers["X-RateLimit-Reset"]
            Write-Warning "Rate Limit: $rateLimit"
            Write-Warning "Remaining: $rateLimitRemaining"
            Write-Warning "Reset Time: $([DateTimeOffset]::FromUnixTimeSeconds($rateLimitReset).LocalDateTime)"
        }
        return $null
    }
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
$totalSize = 0
if ($repoDetails) {
    $repoDetails | ForEach-Object {
        if ($_.Size) {
            $totalSize += $_.Size
        }
    }
}

$summary = @{
    RepositoryCount = if ($repoDetails) { $repoDetails.Count } else { 0 }
    TotalRepoSize = $totalSize
    TeamCount = if ($teamDetails) { $teamDetails.Count } else { 0 }
    MemberCount = if ($memberDetails) { $memberDetails.Count } else { 0 }
    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$summary | ConvertTo-Json | Out-File "$outputPath\summary.json"

Write-Host "GitHub organization details have been exported to the 'github-details' directory."