# End a lab session WITHOUT losing your work.
#
# Stops all five instances (disks and everything you configured are kept) and
# removes the NAT gateway, which otherwise bills around the clock. Parked cost
# is EBS storage only, roughly $18/month. Bring the lab back with unpark.ps1.
#
# Usage (from anywhere):  .\scripts\park.ps1
# Only run `terraform destroy` when you want to throw the whole build away.

$ErrorActionPreference = "Stop"
if (-not $env:AWS_PROFILE) { $env:AWS_PROFILE = "lab-sso" }
$tf = Join-Path $PSScriptRoot "..\terraform"

$region = terraform -chdir="$tf" output -raw aws_region
$ids = @((terraform -chdir="$tf" output -json instance_ids | ConvertFrom-Json).PSObject.Properties.Value)
if ($ids.Count -eq 0) { throw "No instance IDs in Terraform output. Is the lab applied?" }

Write-Host "Stopping $($ids.Count) instances..."
aws ec2 stop-instances --region $region --instance-ids @ids | Out-Null
aws ec2 wait instance-stopped --region $region --instance-ids @ids
if ($LASTEXITCODE -ne 0) { throw "Instances did not reach 'stopped'. Check the EC2 console before continuing." }

Write-Host "Removing NAT gateway..."
terraform -chdir="$tf" apply -var nat_enabled=false -auto-approve
if ($LASTEXITCODE -ne 0) { throw "terraform apply failed. The NAT gateway may still exist and be billing." }

Write-Host "Lab parked. Instances stopped, NAT gateway removed. Resume with .\scripts\unpark.ps1"
