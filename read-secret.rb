require 'vault'
require 'base64'

require 'pry-byebug'

customer_name = 'lyndsey'

Vault.address = "http://127.0.0.1:8200"
secret  = Vault.logical.read("secret/data/custom-mobile-apps/keychains/#{customer_name}")
encoded_keychain_data = secret.data.dig(:data, :keychain_encoded_data)
keychain_password = secret.data.dig(:data, :keychain_password)

decoded_keychain_filepath = File.expand_path("~/Library/Keychains/#{customer_name}.keychain-db")
File.open(decoded_keychain_filepath, "wb") do |file|
  file.write(Base64.decode64(encoded_keychain_data))
end



