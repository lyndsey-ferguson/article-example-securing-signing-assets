#!/usr/bin/env sh

set -e
set -x

# Restrict standard system command line tools.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

check_token_for_create_update_capabilities() {
  local secret_path
  secret_path=$1

  capabilities=$(curl -s --request POST --header "X-Vault-Token: $VAULT_TOKEN" \
    --data "{\"path\":\"$secret_path\"}" \
    $VAULT_ADDR/v1/sys/capabilities-self | jq  ".capabilities")

  has_create_update_capabilities="$(echo $capabilities | jq "[. | sort | index(\"create\"), index(\"update\")] == [0, 1]")"

  if [ "$has_create_update_capabilities" == "false" ]; then
    echo "Error: current VAULT_TOKEN does not allow to write to '$secret_path'"
    exit 1
  fi
}

check_token_for_create_update_capabilities "secret/data/custom-mobile-apps/keystores/*"

KEYSTORE_FILEPATH=$1
if [ ! -f "$KEYSTORE_FILEPATH" ]; then
  echo "Error: the first parameter must be an existing keystore filepath"
  exit 1
fi

# base64 encode the keystore file, without extra newlines
KEYSTORE_ENCODED_DATA="$(base64 -b 0 "$KEYSTORE_FILEPATH")"
read -sp "Keystore password: " KEYSTORE_PASSWORD
echo ""
ENCRYPTED_KEYSTORE_PASSWORD_FILEPATH=$(mktemp /tmp/XXXXXX-encrypted-keystore-password.enc)
echo "$KEYSTORE_PASSWORD" | tr -d '\n' | openssl rsautl -encrypt -pubin -inkey vault/public-mobile-apps.key -out $ENCRYPTED_KEYSTORE_PASSWORD_FILEPATH

ENCODED_ENCRYPTED_KEYSTORE_PASSWORD="$(cat "$ENCRYPTED_KEYSTORE_PASSWORD_FILEPATH" | base64 -b 0)"
read -p "Company name: " COMPANY_NAME
echo ""
echo "$ENCODED_ENCRYPTED_KEYSTORE_PASSWORD" > "${COMPANY_NAME}-encoded-encrypted-keystore-password.enc"
rm $ENCRYPTED_KEYSTORE_PASSWORD_FILEPATH

# perform the curl commands:
curl \
 -H "X-Vault-Token: $VAULT_TOKEN" \
 -H "Content-Type: application/json" \
 -X POST \
 -d "{\"data\": {\"keystore_encoded_data\":\"$KEYSTORE_ENCODED_DATA\", \"encoded_encrypted_keystore_password\": \"$ENCODED_ENCRYPTED_KEYSTORE_PASSWORD\"}}" \
 "$VAULT_ADDR/v1/secret/data/custom-mobile-apps/keystores/$COMPANY_NAME"

echo "Keystore data secured into Vault"
unset VAULT_TOKEN
unset ENCODED_ENCRYPTED_KEYSTORE_PASSWORD
unset ENCRYPTED_KEYSTORE_PASSWORD_FILEPATH
unset KEYSTORE_ENCODED_DATA

