#!/usr/bin/env bash
set -euo pipefail

# Pass the lab user as the first argument or set LAB_USER in the environment.
LAB_USER="${1:-${LAB_USER:-}}"

if [[ -z "$LAB_USER" ]]; then
  echo "Usage: $0 <your-lab-user>" >&2
  echo "   or: LAB_USER=<your-lab-user> $0" >&2
  exit 1
fi

ACCT="$(aws sts get-caller-identity --query Account --output text)"
ROLE_ARN="arn:aws:iam::${ACCT}:role/nimbus/nimbus-onboarding-svc"
TARGET_USER_ARN="arn:aws:iam::${ACCT}:user/nimbus/james"
LAB_USER_ARN="arn:aws:iam::${ACCT}:user/${LAB_USER}"

run_sim() {
  local label="$1"
  shift
  echo "=== ${label} ==="
  aws iam simulate-principal-policy \
    --policy-source-arn "$ROLE_ARN" \
    --query 'EvaluationResults[].[EvalActionName,EvalDecision]' \
    --output text \
    "$@"
}

# 1. Attach AdministratorAccess
run_sim "1. Attach AdministratorAccess" \
  --action-names iam:AttachUserPolicy \
  --resource-arns "$TARGET_USER_ARN" \
  --context-entries "ContextKeyName=iam:PolicyARN,ContextKeyValues=arn:aws:iam::aws:policy/AdministratorAccess,ContextKeyType=string"

# 2. Attach the MFA guard
run_sim "2. Attach the MFA guard" \
  --action-names iam:AttachUserPolicy \
  --resource-arns "$TARGET_USER_ARN" \
  --context-entries "ContextKeyName=iam:PolicyARN,ContextKeyValues=arn:aws:iam::${ACCT}:policy/nimbus/Nimbus-RequireMFA,ContextKeyType=string"

# 3. Touch your own lab user
run_sim "3. Touch your own lab user (${LAB_USER})" \
  --action-names iam:CreateLoginProfile \
  --resource-arns "$LAB_USER_ARN"