import ProjectDescription
import ProjectInfraPlugin

/// Canonical bundle identifiers shared across manifests.
///
/// Keeping bundle IDs in one place prevents drift between the host app and its extensions when:
/// - local bundle ID suffixes are enabled (`TUIST_BUNDLE_ID_SUFFIX`), or
/// - targets are split across multiple `Project.swift` files.
public enum AppIdentifiers {
    /// iOS host app bundle identifier.
    public enum iOSApp {
        /// Base bundle identifier without any local environment suffix.
        public static var baseBundleId: String {
            Environment.iosBaseBundleId.getString(default: "com.acme.app")
        }

        /// Bundle identifier with any configured local environment suffix applied.
        public static var bundleId: String { ConfigurationHelper.applyEnvironmentSuffix(to: baseBundleId) }
    }

    /// macOS host app bundle identifier.
    public enum macOSApp {
        /// Base bundle identifier without any local environment suffix.
        public static var baseBundleId: String {
            Environment.macosBaseBundleId.getString(default: "com.acme.mac-app")
        }

        /// Bundle identifier with any configured local environment suffix applied.
        public static var bundleId: String { ConfigurationHelper.applyEnvironmentSuffix(to: baseBundleId) }
    }
}
