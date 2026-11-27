#!/usr/bin/env bash
set -euo pipefail

cd terraform

SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=lab02-web \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [[ -z "$SG" || "$SG" == "None" ]]; then
  echo "Error: Security group 'lab02-web' not found." >&2
  exit 1
fi

RULE=$(aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values="$SG" \
  --query 'SecurityGroupRules[?!IsEgress && FromPort==`8443`].SecurityGroupRuleId' \
  --output text)

if [[ -z "$RULE" || "$RULE" == "None" ]]; then
  echo "Error: Ingress rule for port 8443 not found in security group '$SG'." >&2
  exit 1
fi

aws ec2 modify-security-group-rules \
  --group-id "$SG" \
  --security-group-rules "SecurityGroupRuleId=$RULE,SecurityGroupRule={IpProtocol=tcp,FromPort=8443,ToPort=8443,CidrIpv4=0.0.0.0/0}"

terraform plan