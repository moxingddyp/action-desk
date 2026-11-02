# Android workbench 1.6.1 (versionCode 13)

Native Java Android client with actions, device telemetry, daily information and desktop widgets. Package identity remains `com.cxy.workbench`. No server address, credentials, private device configuration or data is embedded.

Import a local connection JSON using Settings. See `connection.example.json`; generate your own role-scoped tokens on the server. The optional phoneToken only authorizes phone sampling uploads. HTTPS endpoints are accepted. HTTP is restricted in application code to literal loopback or CGNAT (100.64.0.0/10) addresses; a trusted private network is required for cleartext. Dynamic endpoints require Android cleartext permission; ConnectionSpec validates every service/update request before authorization headers are sent. No redirects are followed. Connection values remain in app-private preferences. Changing server endpoints does not automatically copy existing cached data to a new server.

Updates use the imported server endpoint, bounded manifest/download paths, byte/hash/version/package/signature verification and the Android system installation confirmation. Public builds use the existing release signing certificate, with private signing material excluded. They may replace same-signature builds, but do not import any connection automatically. Self-builds require your own private signing key; differently signed APKs cannot replace an existing installation. Back up your configuration before any deliberate uninstall. The repository and APK do not contain the publisher's signing key.

## Windows build

Use PowerShell 7, Python 3 and an existing JDK 21/Android 36 build runtime. Build preparation is optional if tools are already installed. Each operator must review and accept Android SDK terms independently:

```powershell
python prepare_build.py --runtime C:/BuildTools/android --accept-sdk-license
./build.ps1 -Runtime C:/BuildTools/android -Output C:/BuildOutput/workbench -Keystore C:/PrivateKeys/release.jks -PasswordFile C:/PrivateKeys/password.txt -KeyAlias your-alias
```

Signing files must stay outside this repository. No script creates or replaces your signing key. Android SDK/JDK tools, third-party binaries and model/data downloads are not distributed in this package. The SDK terms are retained in ANDROID-SDK-LICENSE.txt; client source is covered by the root MIT license.

This public adaptation compiles and preserves existing UI/model tests, with endpoint validation tests added. It has not been installed or exercised against a new user's server or phone. Earlier private deployment checks apply to the private predecessor, not a new public installation.
