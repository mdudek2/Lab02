#!/usr/bin/env bash
set -euo pipefail

cd terraform

URL="$(terraform output -raw console_url)"
IP="${URL#https://}"
IP="${IP%:8443}"

# 1. HTTPS works, plain HTTP does not
echo "=== 1. HTTPS vs plain HTTP ==="
curl -sk -o /dev/null -w "https: %{http_code}\n" "${URL}/login"

set +e
curl -s --max-time 5 "http://${IP}:8443/login"
HTTP_RC=$?
set -e
echo "plain http exit code: ${HTTP_RC}"

# 2. Security headers added by the app
echo "=== 2. Security headers ==="
curl -skI "${URL}/login" | grep -i -E 'strict-transport|x-frame|content-security|x-content-type|cache-control|referrer' || true

# 3. SSH and the private service ports are closed to you (a timeout means a firewall dropped the packet)
echo "=== 3. Port checks ==="
for P in 22 5001 8080; do
  if timeout 5 bash -c "</dev/tcp/${IP}/${P}" 2>/dev/null; then
    echo "port ${P} OPEN"
  else
    echo "port ${P} closed"
  fi
done

# 4 The private services have no public address at all
echo "=== 4. Running lab02-* instances ==="
aws ec2 describe-instances \
  --filters Name=tag:Name,Values='lab02-*' Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`]|[0].Value,PrivateIpAddress,PublicIpAddress,SubnetId]' \
  --output table

# 5 Bucket protections, read from AWS
echo "=== 5. S3 bucket protections ==="
ACCT="$(aws sts get-caller-identity --query Account --output text)"
B="lab02-nimbus-${ACCT}"
aws s3api get-public-access-block --bucket "$B" --query PublicAccessBlockConfiguration
aws s3api get-bucket-encryption --bucket "$B" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault'
aws s3api get-bucket-versioning --bucket "$B"

# 6 Lockout: six wrong passwords for a user that does not exist. Expect 200 five times, then 429
echo "=== 6. Lockout check (run last) ==="
for i in 1 2 3 4 5 6; do
  curl -sk -o /dev/null -w "%{http_code} " -d "username=nobody&password=wrong" "${URL}/login"
done
echo