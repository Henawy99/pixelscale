fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android user

```sh
[bundle exec] fastlane android user
```

Build and upload USER app to Google Play Console (Internal Testing)

### android admin

```sh
[bundle exec] fastlane android admin
```

Build and upload ADMIN app to Google Play Console (Internal Testing)

### android partner

```sh
[bundle exec] fastlane android partner
```

Build and upload PARTNER app to Google Play Console (Internal Testing)

### android upload_user

```sh
[bundle exec] fastlane android upload_user
```

Quick upload USER app AAB to Play Console (skip build)

### android upload_partner

```sh
[bundle exec] fastlane android upload_partner
```

Quick upload PARTNER app AAB to Play Console (skip build)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
