#!/usr/bin/env bash
set -euo pipefail

export AWS_DEFAULT_REGION=us-east-2

T="/etc/nimbus/tls"
D="https://10.20.11.11:5003/api/employees"

run_curl_expect_fail() {
  set +e
  "$@"
  local rc=$?
  set -e
  return 0
}

# 1. No client certificate: the TLS handshake itself fails
echo "=== 1. No client certificate ==="
run_curl_expect_fail curl -s -o /dev/null -w "1 no client certificate (exit %{exitcode}): %{http_code}\n" \
  --cacert "${T}/ca.pem" \
  "$D"

# 2. Certificate, but no internal token
echo "=== 2. Certificate, no token ==="
run_curl_expect_fail curl -s -o /dev/null -w "2 certificate, no token (exit %{exitcode}): %{http_code}\n" \
  --cacert "${T}/ca.pem" \
  --cert "${T}/service.pem" \
  --key "${T}/service.key" \
  "$D"

# 3. Certificate and token, but no admin JWT
echo "=== 3. Certificate and token, no JWT ==="
TOKEN="$(aws ssm get-parameter \
  --name /nimbus/internal-token/current \
  --with-decryption \
  --query Parameter.Value \
  --output text)"

run_curl_expect_fail curl -s -o /dev/null -w "3 certificate and token, no JWT (exit %{exitcode}): %{http_code}\n" \
  --cacert "${T}/ca.pem" \
  --cert "${T}/service.pem" \
  --key "${T}/service.key" \
  -H "X-Internal-Token: ${TOKEN}" \
  "$D"

# 4. The web server's role cannot do anything else
echo "=== 4. Role least-privilege check ==="
set +e
aws iam list-users 2>&1 | tail -1
aws s3 ls 2>&1 | tail -1
set -e

# 5. IMDSv2: a plain request for credentials is refused, a token based one works
echo "=== 5. IMDSv2 check ==="
curl -s -o /dev/null -w "metadata without token: %{http_code}\n" \
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/"

IMDS_TOKEN="$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")"

curl -s -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
echo