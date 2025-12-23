import ProjectDescription

public enum BuildEnvironment: String, CaseIterable {
    case debug
    case release

    public var configurationName: ConfigurationName {
        switch self {
        case .debug: return .debug
        case .release: return .release
        }
    }

    public func settings() -> SettingsDictionary {
        var settings: SettingsDictionary = [:]

        settings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.0"
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

    public func configuration() -> Configuration {
        switch self {
        case .debug:
            return .debug(name: configurationName, settings: settings())
        case .release:
            return .release(name: configurationName, settings: settings())
        }
    }
}

public extension Settings {
    static var regular: Settings {
        .settings(
            configurations: BuildEnvironment.allCases.map { $0.configuration() }
        )
    }

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
