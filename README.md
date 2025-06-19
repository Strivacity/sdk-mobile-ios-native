![Strivacity iOS SDK](https://static.strivacity.com/images/ios-native-sdk.png)

See our [Developer Portal](https://www.strivacity.com/learn-support/developer-hub) to get started with developing for the Strivacity product.

# Overview

This SDK allows you to integrate Strivacity's policy-driven journeys into your brand's iOS mobile application using native mobile experiences via [Journey-flow API for native clients](https://docs.strivacity.com/reference/journey-flow-api-for-native-clients).

The SDK uses the [PKCE extension to OAuth](https://tools.ietf.org/html/rfc7636) to ensure the secure exchange of authorization codes in public clients.

## How to use

To use the Strivacity iOS SDK:

If you are using [Swift Package Manager](https://www.swift.org/package-manager/) extend your `Package.swift` file with the following dependency.

```swift
.package(url: "https://github.com/Strivacity/sdk-mobile-ios-native.git", from: "<version>")
```

where `<version>` is the SDK version you want to use.

If you are using an XCode Project use the `File / Add Packages...` option enter the following url: `https://github.com/Strivacity/sdk-mobile-ios-native.git` and select the `sdk-mobile-ios-native` package with the version you want to use.

## Demo Application

A demo application is available in the following repository: [https://github.com/Strivacity/demo-mobile-ios-native](https://github.com/Strivacity/demo-mobile-ios-native)

## Overview

The Strivacity SDK for iOS provides the possibility to build an application which can communicate with Strivacity using OAuth 2.0 PKCE flow.

## Instantiate Native SDK

First, you must create a NativeSDK instance:

```swift
let nativeSDK = NativeSDK(
    issuer: URL(string: "<issuer-url>")!,                   // specifies authentication server domain, e.g.: https://your-domain.tld
    clientId: "<client-id>",                                // specifies OAuth2 client ID
    redirectURI: URL(string: "<redirect-uri>")!,            // specifies the redirect uri, e.g.: strivacity.DemoMobileIOS://native-flow
    postLogoutURI: URL(string: "<post-logout-uri>")!        // specifies the post logout uri, e.g.: strivacity.DemoMobileIOS://native-flow
)

let session = nativeSDK.session                             // store the session to interact with the current account session
```


## Initialize Native SDK

Initialize the NativeSDK instance to prepare the SDK internals and load the existing session, if any.
This is an asynchronous method, and should be treated accordingly.

```swift
try await nativeSDK.initializeSession()
```

This can be done, for example, in the SwiftUI's `onAppear` method on the current view
```swift
VStack {
    // ...
}
.onAppear {
    Task {
        try await nativeSDK.initializeSession()
        loading = false
    }
}
```

## Integrate into your view

The SDK can have three states:
1. Account already logged in
   - `session.profile` is populated
2. Login in progress
   - `session.loginInProgress` is set to `true`
3. No session
   - otherwise

This can be implemented in the following way:

```swift
VStack {
    if loading {
        Text("Loading...")
    } else {
        if let profile = session.profile {
            // (1) implement you logged in screens
        } else if session.loginInProgress {
            // (2) login in progress, display login view
        } else {
            // (3) no active session, you can trigger a login from this state
        }
    }
}
```

### How to launch a login flow

This can be done in location (3) using the `login` method on the `nativeSDK` instance.

```swift
func login(
    parameters: LoginParameters?,           // additional parameters to pass through during login
    onSuccess: @escaping () -> Void,        // callback method that will be called after a successful login
    onError: @escaping (Error) -> Void      // callback method that will be called if an error occures
)
```

The following additional parameters can be set:
```swift
LoginParameters(
    prompt: String? = nil,                              // sets the corresponding parameter in the OAuth2 authorize call
    loginHint: String? = nil,                           // sets the corresponding parameter in the OAuth2 authorize call
    acrValue: String? = nil,                            // sets the corresponding parameter in the OAuth2 authorize call
    scopes: [String]? = nil,                            // sets the corresponding parameter in the OAuth2 authorize call
    prefersEphemeralWebBrowserSession: Bool = false     // option for `ASWebAuthenticationSession` in case of fallback see: https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/prefersephemeralwebbrowsersession
)
```

Example usage:
```swift
Button("Login") {
    Task {
        self.error = nil
        await nativeSDK.login(
            parameters: LoginParameters(
                scopes: ["openid", "profile", "offline"],
                prefersEphemeralWebBrowserSession: true
            ),
            onSuccess: {
            },
            onError: { err in
                switch err {
                case let NativeSDKError.oidcError(error: _, errorDescription: errorDescription):
                    self.error = errorDescription
                case NativeSDKError.hostedFlowCanceled:
                    self.error = "Hosted login canceled"
                case NativeSDKError.sessionExpired:
                    self.error = "Session expired"
                default:
                    print(err)
                    self.error = "N/A"
                }
            }
        )
    }
}
if let error = error {
    Text(error)
        .foregroundColor(.red)
}
```

### Display the login view

This can be done in location (2) using the `LoginView` class.

```swift
LoginView(nativeSDK: nativeSDK)
```

The rendered layout and widgets can be customized by passing a ViewBuilder as a second parameter to the constructor.
For an example, see Strivacity's CustomizedDemo application.

During login, it's possible to programmatically cancel a login flow using the `cancelFlow` method on the `nativeSDK` instance.

For example:
```swift
 VStack {
    Form {
        LoginView(nativeSDK: nativeSDK)
            .padding()
    }
    Spacer()
    Button("Cancel login") {
        nativeSDK.cancelFlow()
    }
}
```

### Handling a logged-in session

The current session information is available in location (1).

The retrieved claims can be accessed in the `session.profile`.
For example, displaying the `given_name` claim with validation can be done like:
```swift
Text(profile.claims["given_name"] as? String ?? "N/A")
```

The access token can be retrieved using the `getAccessToken` method on the `nativeSDK` instance. Keep in mind that if the access token is expired and a refresh token is available, this method will try to renew the access token.

To validate if the current session's access token is still valid, the `isAuthenticated` method can be called on the `nativeSDK` instance. This call will also try to refresh the access token, if possible.

To trigger a logout the `logout` method can be called on the `nativeSDK` instance.

Example for using the methods above:
```swift
Text("Authenticated: ")
Text(profile.claims["given_name"] as? String ?? "N/A")

if let accessToken = accessToken {
    Text("Access token: \(accessToken)")
} else {
    Button("Get access token") {
        Task {
            accessToken = try? await nativeSDK.getAccessToken()
        }
    }
}

Button("Logout") {
    Task {
        try await nativeSDK.logout()
    }
}
```

## Author

Strivacity: [opensource@strivacity.com](mailto:opensource@strivacity.com)

## License

Strivacity is available under the Apache License, Version 2.0. See the [LICENSE](./LICENSE) file for more info.

## Vulnerability Reporting

The [Guidelines for responsible disclosure](https://www.strivacity.com/report-a-security-issue) details the procedure for disclosing security issues.
Please do not report security vulnerabilities on the public issue tracker.