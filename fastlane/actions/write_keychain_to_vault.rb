module Fastlane
  module Actions
    require 'vault'
    require 'tmpdir'
    require 'pry-byebug'

    class WriteKeychainToVaultAction < Action
      def self.run(params)
        Vault.address = params[:vault_addr]
        Vault.token = params[:vault_token]

        encoded_keychain_data = Base64.encode64(File.open(params[:keychain_path], 'rb').read)
        keychain_name = params[:keychain_name]
        keychain_password = params[:keychain_password]

        # read private key from Vault
        # read encrypted password from given encrypted password file path
        # decrypt password using private key
        byebug
        Vault.logical.write(
          "secret/data/custom-mobile-apps/keychains/#{keychain_name}",
          data: {
            keychain_encoded_data: encoded_keychain_data,
            keychain_password: keychain_password
          }
        )
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
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
            description: "The name of the keychain to store in the custom mobile apps Vault secret"
          ),
          FastlaneCore::ConfigItem.new(
            key: :keychain_path,
            description: "The file path to the keychain to add to Vault"
          ),
          FastlaneCore::ConfigItem.new(
            key: :keychain_password,
            description: "The keychain password to be store along with the given keychain in the custom mobile apps Vault secret",
            sensitive: true
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
