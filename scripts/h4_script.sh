#!/usr/bin/env bash
set -euo pipefail

FLOW_LOG_GROUP="${FLOW_LOG_GROUP:-/lab02/flow}"
APP_LOG_GROUP="${APP_LOG_GROUP:-/lab02/app}"
FLOW_MAX_ITEMS="${FLOW_MAX_ITEMS:-10}"
APP_MAX_ITEMS="${APP_MAX_ITEMS:-5}"
LOGIN_FILTER_PATTERN="${LOGIN_FILTER_PATTERN:-\"login_failed\"}"

echo "=== Recent flow logs ($FLOW_LOG_GROUP, max $FLOW_MAX_ITEMS) ==="
aws logs filter-log-events \
  --log-group-name "$FLOW_LOG_GROUP" \
  --max-items "$FLOW_MAX_ITEMS" \
  --query 'events[].message' \
  --output text

echo ""
echo "=== Failed login app logs ($APP_LOG_GROUP, max $APP_MAX_ITEMS) ==="
aws logs filter-log-events \
  --log-group-name "$APP_LOG_GROUP" \
  --filter-pattern "$LOGIN_FILTER_PATTERN" \
  --max-items "$APP_MAX_ITEMS" \
  --query 'events[].message' \
  --output text