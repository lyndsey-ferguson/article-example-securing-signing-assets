
path "secret/custom-mobile-apps/keychains/*" {
  capabilities = ["create", "update"]
}

path "secret/custom-mobile-apps/apns_keys/*" {
  capabilities = ["create", "update"]
}

path "secret/custom-mobile-apps/keystores/*" {
  capabilities = ["create", "update"]
}
