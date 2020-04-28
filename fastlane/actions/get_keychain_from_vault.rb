module Fastlane
  module Actions
    require 'openssl'
    require 'vault'
    require 'tmpdir'

    class GetKeychainFromVaultAction < Action
      def self.run(params)
        Vault.address = params[:vault_addr]
        Vault.token = params[:vault_token]

        private_key, private_key_passphrase = private_key_data
        decrypter = OpenSSL::PKey::RSA.new(private_key, private_key_passphrase)

        keychain_name = params[:keychain_name]
        encoded_keychain_data, encrypted_keychain_password = keychain_data(keychain_name)
        keychain_password = decrypter.private_decrypt(encrypted_keychain_password)
        
        decoded_keychain_filepath = params[:keychain_path] || tmp_keychain_filepath(keychain_name)

        File.open(decoded_keychain_filepath, 'wb') do |f|
          f.write(Base64.decode64(encoded_keychain_data))
        end

        if params[:keychain_path].nil?
          at_exit do
            FileUtils.rm_rf(decoded_keychain_filepath)
          end
        end

        return {
          keychain_path: decoded_keychain_filepath,
          keychain_password: keychain_password
        }
      end

      def self.tmp_keychain_filepath
          keychain_name = "#{SecureRandom.urlsafe_base64}.keychain-db"
          File.join(Dir.tmpdir, keychain_name)
      end

      def self.keychain_data(keychain_name)
        secret_path = "secret/data/custom-mobile-apps/keychains/#{keychain_name}"
        keychain_secret = Vault.logical.read(secret_path)
        encoded_keychain_data = keychain_secret.data.dig(:data, :keychain_encoded_data)
        encoded_encrypted_keychain_password  = keychain_secret.data.dig(:data, :encoded_encrypted_keychain_password)
        encrypted_keychain_password = Base64.decode64(encoded_encrypted_keychain_password)
        
        [encoded_keychain_data, encrypted_keychain_password]
      end

      def self.private_key_data
        secret_path = "secret/data/custom-mobile-apps/crypto"
        crypto_secret = Vault.logical.read(secret_path)

        encoded_private_key = crypto_secret.data.dig(:data, :encoded_private_key)
        passphrase = crypto_secret.data.dig(:data, :passphrase)
        
        private_key = Base64.decode64(encoded_private_key)
        [private_key, passphrase]
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Gets a given keychain from Vault and unlocks it"
      end

      def self.details
        "Gets a given keychain and its encrypted password from Vault. Decrypts the encrypted password provides both to the callee"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :vault_addr,
            env_name: "VAULT_ADDR", 
            description: "The address of the Vault server expressed as a URL and port, for example: https://127.0.0.1:8200/",
          ),
          FastlaneCore::ConfigItem.new(
            key: :vault_token,
            env_name: "VAULT_TOKEN",
            description: "Vault authentication token",
            is_string: false, 
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :keychain_name,
            description: "The name of the custom mobile apps keychain"
          ),
          FastlaneCore::ConfigItem.new(
            key: :keychain_path,
            description: "Where to write the retrieved keychain. Defaults to a temporary file that is deleted when the Ruby process unloads",
            optional: true
          )
        ]
      end


      def self.return_value
        "A hash containing a :keychain_path and a :keychain_password"   
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
