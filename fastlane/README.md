fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
## iOS
### ios keychain_to_vault_test
```
fastlane ios keychain_to_vault_test
```
Demonstrate how to write a keychain to Vault
### ios keychain_from_vault_test
```
fastlane ios keychain_from_vault_test
```
Demonstrate how to get a keychain from Vault and unlock it
### ios tmp_keychain_from_vault_test
```
fastlane ios tmp_keychain_from_vault_test
```
Demonstrate how to get a temporary keychain from Vault and unlock it

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
