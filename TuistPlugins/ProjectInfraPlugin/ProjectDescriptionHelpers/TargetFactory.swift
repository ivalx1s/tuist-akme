import ProjectDescription

public enum TargetFactory {
    private static func deploymentTargets(for destinations: Destinations) -> DeploymentTargets {
        let platforms = destinations.platforms
        return .multiplatform(
            iOS: platforms.contains(.iOS) ? "16.0" : nil,
            macOS: platforms.contains(.macOS) ? "13.0" : nil,
            watchOS: nil,
            tvOS: nil,
            visionOS: nil
        )
    }

    public static func makeInterface(
        module: ModuleID,
        destinations: Destinations,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: module.interfaceTarget,
            destinations: destinations,
            product: .framework,
            bundleId: "com.acme.\(module.name).interface",
            deploymentTargets: deploymentTargets(for: destinations),
            sources: ["Interface/**"],
            dependencies: dependencies,
            settings: .regular
        )
    }

    public static func makeImpl(
        module: ModuleID,
        destinations: Destinations,
        product: Product,
        dependencies: [TargetDependency],
        resources: ResourceFileElements?,
        additionalSettings: SettingsDictionary = [:]
    ) -> Target {
        let settings: Settings = {
            guard !additionalSettings.isEmpty else { return .regular }
            return .settings(
                configurations: BuildEnvironment.allCases.map { environment in
                    let merged = environment
                        .settings()
                        .merging(additionalSettings) { _, new in new }
                    switch environment {
                    case .debug:
                        return .debug(name: environment.configurationName, settings: merged)
                    case .release:
                        return .release(name: environment.configurationName, settings: merged)
                    }
                }
            )
        }()

        return .target(
            name: module.implTarget,
            destinations: destinations,
            product: product,
            bundleId: "com.acme.\(module.name)",
            deploymentTargets: deploymentTargets(for: destinations),
            sources: ["Sources/**"],
            resources: resources,
            dependencies: dependencies,
            settings: settings
        )
    }

    public static func makeTesting(
        module: ModuleID,
        destinations: Destinations,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: module.testingTarget,
            destinations: destinations,
            product: .staticFramework,
            bundleId: "com.acme.\(module.name).testing",
            deploymentTargets: deploymentTargets(for: destinations),
            sources: ["Testing/**"],
            dependencies: dependencies,
            settings: .regular
        )
    }

    public static func makeTests(
        module: ModuleID,
        destinations: Destinations,
        dependencies: [TargetDependency]
    ) -> Target {
        .target(
            name: module.testsTarget,
            destinations: destinations,
            product: .unitTests,
            bundleId: "com.acme.\(module.name).tests",
            deploymentTargets: deploymentTargets(for: destinations),
            sources: ["Tests/**"],
            dependencies: dependencies,
            settings: .regular
        )
    }

    public static func makeExtension(
        name: String,
        destinations: Destinations,
        product: Product,
        extensionPointIdentifier: String = "com.apple.widgetkit-extension",
        sources: SourceFilesList = ["Sources/**"],
        dependencies: [TargetDependency],
        resources: ResourceFileElements? = nil
    ) -> Target {
        .target(
            name: name,
            destinations: destinations,
            product: product,
            bundleId: "com.acme.app.\(name.lowercased())",
            deploymentTargets: deploymentTargets(for: destinations),
            infoPlist: .extendingDefault(with: [
                "NSExtension": [
                    "NSExtensionPointIdentifier": .string(extensionPointIdentifier),
                ],
            ]),
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            settings: .regular
        )
    }
}
