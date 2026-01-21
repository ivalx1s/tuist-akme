// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescription

private let iosMinVersion = Environment.iosMinVersion.getString(default: "16.0")
private let macosMinVersion = Environment.macosMinVersion.getString(default: "13.0")

private enum BuildEnvironment: CaseIterable {
    case debug
    case release

    var configurationName: ConfigurationName {
        switch self {
        case .debug: return .debug
        case .release: return .release
        }
    }

    func settings() -> SettingsDictionary {
        var settings: SettingsDictionary = [:]

        settings["IPHONEOS_DEPLOYMENT_TARGET"] = .string(iosMinVersion)
        settings["MACOSX_DEPLOYMENT_TARGET"] = .string(macosMinVersion)
        settings["SWIFT_VERSION"] = "5.9"
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

    func configuration(with settings: SettingsDictionary) -> Configuration {
        switch self {
        case .debug:
            return .debug(name: configurationName, settings: settings)
        case .release:
            return .release(name: configurationName, settings: settings)
        }
    }
}

private extension Settings {
    static var externalDependencyModuleSettings: Settings {
        .settings(
            configurations: BuildEnvironment.allCases.map { environment in
                let settings = environment.settings()
                return environment.configuration(with: settings)
            }
        )
    }
}

let packageSettings = PackageSettings(
    productTypes: [
        "Algorithms": .framework,
        "RealModule": .framework,
        "_NumericsShims": .framework,
    ],
    baseSettings: .externalDependencyModuleSettings
)
#endif

let package = Package(
    name: "AcmeAppDependencies",
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.1"),
        // Add other dependencies here
    ]
)
