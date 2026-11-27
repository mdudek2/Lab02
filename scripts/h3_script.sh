#!/usr/bin/env bash
set -euo pipefail

# Read Cognito outputs from Terraform without leaving the script in terraform/
read -r CID POOL PW < <(
  cd terraform
  printf '%s\t%s\t%s\n' \
    "$(terraform output -raw cognito_client_id)" \
    "$(terraform output -raw cognito_user_pool_id)" \
    "$(terraform output -raw admin_password)"
)

if [[ -z "$CID" || -z "$POOL" || -z "$PW" ]]; then
  echo "Error: one or more Terraform outputs are empty." >&2
  exit 1
fi

SESSION=$(
  aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id "$CID" \
    --auth-parameters "USERNAME=admin,PASSWORD=$PW" \
    --query Session \
    --output text
)

read -rp "6 digit code: " CODE

TOKEN=$(
  aws cognito-idp respond-to-auth-challenge \
    --client-id "$CID" \
    --challenge-name SOFTWARE_TOKEN_MFA \
    --session "$SESSION" \
    --challenge-responses "USERNAME=admin,SOFTWARE_TOKEN_MFA_CODE=$CODE" \
    --query AuthenticationResult.AccessToken \
    --output text
)

if [[ -z "$TOKEN" || "$TOKEN" == "None" ]]; then
  echo "Error: failed to retrieve AccessToken." >&2
  exit 1
fi

export TOKEN
export ISS="https://cognito-idp.us-east-2.amazonaws.com/${POOL}"

.venv/bin/pip install -q PyJWT cryptography

.venv/bin/python - <<'PY'
import base64
import json
import os
import jwt

tok = os.environ["TOKEN"]
head, payload, sig = tok.split(".")


def decode_part(part: str) -> dict:
    padded = part + "=" * (-len(part) % 4)
    return json.loads(base64.urlsafe_b64decode(padded))


print("HEADER ", decode_part(head))
print(
    "PAYLOAD",
    {
        k: v
        for k, v in decode_part(payload).items()
        if k in ("iss", "client_id", "token_use", "username", "cognito:groups", "exp")
    },
)

jwks_url = os.environ["ISS"] + "/.well-known/jwks.json"
key = jwt.PyJWKClient(jwks_url).get_signing_key_from_jwt(tok).key

verified = jwt.decode(tok, key, algorithms=["RS256"], issuer=os.environ["ISS"])
print("genuine token verifies for:", verified["username"])

claims = decode_part(payload)
claims["username"] = "mallory"
claims["cognito:groups"] = ["admins"]
forged = (
    head
    + "."
    + base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    + "."
    + sig
)

try:
    jwt.decode(forged, key, algorithms=["RS256"], issuer=os.environ["ISS"])
except jwt.PyJWTError as e:
    print("forged token refused:", type(e).__name__)
PY