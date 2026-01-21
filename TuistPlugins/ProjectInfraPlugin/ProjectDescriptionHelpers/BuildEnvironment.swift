import ProjectDescription

/// Canonical build configurations used across the project.
///
/// This provides a single place for default build settings and configuration names so target
/// factories stay consistent.
public enum BuildEnvironment: String, CaseIterable {
    case debug
    case release

    /// The Tuist configuration name corresponding to this build environment.
    public var configurationName: ConfigurationName {
        switch self {
        case .debug: return .debug
        case .release: return .release
        }
    }

    /// Default build settings for this environment.
    public func settings() -> SettingsDictionary {
        let iosMinVersion = Environment.iosMinVersion.getString(default: "16.0")
        let macosMinVersion = Environment.macosMinVersion.getString(default: "13.0")

        var settings: SettingsDictionary = [:]

        settings["IPHONEOS_DEPLOYMENT_TARGET"] = .string(iosMinVersion)
        settings["MACOSX_DEPLOYMENT_TARGET"] = .string(macosMinVersion)
        settings["SWIFT_VERSION"] = "6.2"
        settings["STRING_CATALOG_GENERATE_SYMBOLS"] = "YES"
        settings["ENABLE_USER_SCRIPT_SANDBOXING"] = "YES"
        settings["ENABLE_MODULE_VERIFIER"] = "YES"

        switch self {
        case .debug:
            settings["ENABLE_TESTABILITY"] = "YES"
            settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) DEBUG"
            settings["GCC_PREPROCESSOR_DEFINITIONS"] = "$(inherited) DEBUG=1"
            settings["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone"
            settings["SWIFT_COMPILATION_MODE"] = "singlefile"
            settings["DEBUG_INFORMATION_FORMAT"] = "dwarf"
        case .release:
            settings["ENABLE_TESTABILITY"] = "NO"
            settings["SWIFT_OPTIMIZATION_LEVEL"] = "-O"
            settings["SWIFT_COMPILATION_MODE"] = "wholemodule"
            settings["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
        }

        return settings
    }

    /// Builds a Tuist `Configuration` for this environment.
    public func configuration() -> Configuration {
        switch self {
        case .debug:
            return .debug(name: configurationName, settings: settings())
        case .release:
            return .release(name: configurationName, settings: settings())
        }
    }
}

/// Convenience `Settings` constructors used by project factories.
public extension Settings {
    /// Standard project settings used by most targets.
    static var regular: Settings {
        .settings(
            configurations: BuildEnvironment.allCases.map { $0.configuration() }
        )
    }

    /// Settings for external dependency targets (SPM or prebuilt binaries).
    ///
    /// These targets typically don't need additional project-specific overrides beyond the
    /// environment defaults.
    static var externalDependencyModuleSettings: Settings {
        .settings(
            configurations: BuildEnvironment.allCases.map { environment in
                let settings = environment.settings()
                switch environment {
                case .debug:
                    return .debug(name: environment.configurationName, settings: settings)
                case .release:
                    return .release(name: environment.configurationName, settings: settings)
                }
            }
        )
    }
}
