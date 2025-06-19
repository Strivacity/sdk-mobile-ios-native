# Set the destination for the build directory of the SDK package.
derived_data_path=.build/DerivedData

# Build the SDK package using xcodebuild.
xcodebuild build -scheme SdkMobileIOSNative -sdk "`xcrun --sdk iphonesimulator --show-sdk-path`" \
-destination "OS=17.4,name=iPhone 15" -derivedDataPath ${derived_data_path} clean build

# Run Periphery to scan for unused variables.
periphery scan --skip-build --index-store-path $derived_data_path/Index.noindex/DataStore
