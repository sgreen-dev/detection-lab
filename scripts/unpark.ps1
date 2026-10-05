# Resume a parked lab exactly where you left off.
#
# Recreates the NAT gateway (so the private hosts have internet again) and
# starts all five instances. Private IPs do not change across stop/start, so
# the domain, Fleet Server URL and enrolled agents keep working.
#
# Usage (from anywhere):  .\scripts\unpark.ps1
# If the SSO login has expired first run:  aws sso login --profile lab-sso

$ErrorActionPreference = "Stop"
if (-not $env:AWS_PROFILE) { $env:AWS_PROFILE = "lab-sso" }
$tf = Join-Path $PSScriptRoot "..\terraform"

Write-Host "Recreating NAT gateway..."
terraform -chdir="$tf" apply -var nat_enabled=true -auto-approve
if ($LASTEXITCODE -ne 0) { throw "terraform apply failed." }

$region = terraform -chdir="$tf" output -raw aws_region
$outs = terraform -chdir="$tf" output -json instance_ids | ConvertFrom-Json
$ids = @($outs.PSObject.Properties.Value)

Write-Host "Starting $($ids.Count) instances..."
aws ec2 start-instances --region $region --instance-ids @ids | Out-Null
aws ec2 wait instance-running --region $region --instance-ids @ids
if ($LASTEXITCODE -ne 0) { throw "Instances did not reach 'running'. Check the EC2 console." }

Write-Host "Lab running. Give Windows a few minutes to finish booting before connecting."
Write-Host "Kibana tunnel (leave that window open, then browse http://localhost:5601):"
Write-Host "aws ssm start-session --region $region --target $($outs.elastic) --document-name AWS-StartPortForwardingSession --parameters portNumber=5601,localPortNumber=5601"
