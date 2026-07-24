# Migration Guide

## Migrating to 5.0.0

### `NetworkConfiguration`: `customRequestHeaders` → `customRequestHeaderProvider`

The `init(userAgent:customRequestHeaders:)` initializer is deprecated. It accepted a static dictionary of `x-sty-`-prefixed headers and an optional `userAgent` override. Replace it with the new `init(customRequestHeaderProvider:)`:

```swift
// Before (deprecated):
NetworkConfiguration(customRequestHeaders: ["x-sty-app-version": "1.2.3"])

// After:
NetworkConfiguration(customRequestHeaderProvider: { _, _, _ in
    ["x-sty-app-version": "1.2.3"]
})
```

> **Note:** The `userAgent` parameter is only available on the deprecated initializer. With the new initializer, the `User-Agent` header can be set by returning it from the `customRequestHeaderProvider` callback — it will overwrite the platform default.

### `addSdkVersionCustomHeader()` → `NetworkConfiguration.withSdkVersionCustomHeader`

The mutating `addSdkVersionCustomHeader()` function is deprecated. Use the static provider instead:

```swift
// Before (deprecated):
var config = NetworkConfiguration()
config = config.addSdkVersionCustomHeader()

// After:
let config = NetworkConfiguration(
    customRequestHeaderProvider: NetworkConfiguration.withSdkVersionCustomHeader
)
```

To combine the SDK version header with your own headers:

```swift
let config = NetworkConfiguration(
    customRequestHeaderProvider: { uri, method, body in
        var headers = NetworkConfiguration.withSdkVersionCustomHeader(uri, method, body)
        headers["x-sty-app-version"] = "1.2.3"
        return headers
    }
)
```
