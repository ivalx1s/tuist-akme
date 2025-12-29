import ProjectDescription

/// High-level project factories that enforce repository conventions.
///
/// These helpers centralize common project shapes (apps, features, composition roots) and apply
/// architecture rules (for example, external dependency allow-lists).
public enum ProjectFactory {
    /// Creates a host app project that links a composition root and optionally embeds extensions.
    ///
    /// This is the recommended app entry point: the app target depends on a single composition
    /// root (which wires feature implementations) and entitlements are generated from
    /// `capabilities`.
    public static func makeHostApp(
        projectName: String,
        appName: String? = nil,
        bundleId: String,
        destinations: Destinations,
        deploymentTargets: DeploymentTargets? = nil,
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = ["Resources/**"],
        infoPlist: InfoPlist = .default,
        compositionRoot: CompositionRoot,
        embeddedExtensions: [ProjectTargetRef] = [],
        capabilities: [Capability] = [],
        settings: SettingsDictionary = [:],
        developmentTeamId: String? = nil,
        automaticSigning: Bool = true
    ) -> Project {
        let resolvedDeploymentTargets: DeploymentTargets = deploymentTargets ?? {
            let platforms = destinations.platforms
            return .multiplatform(
                iOS: platforms.contains(.iOS) ? "16.0" : nil,
                macOS: platforms.contains(.macOS) ? "13.0" : nil,
                watchOS: nil,
                tvOS: nil,
                visionOS: nil
            )
        }()

        let dependencies: [TargetDependency] =
            [compositionRoot.dependency] + embeddedExtensions.map(\.dependency)

        let targetName = appName ?? projectName
        let entitlements = EntitlementsFactory.make(
            hostBundleId: bundleId,
            destinations: destinations,
            capabilities: capabilities
        )
        let appTarget = TargetFactory.makeApp(
            name: targetName,
            destinations: destinations,
            bundleId: bundleId,
            deploymentTargets: resolvedDeploymentTargets,
            entitlements: entitlements,
            infoPlist: infoPlist,
            sources: sources,
            resources: resources,
            dependencies: dependencies,
            additionalSettings: settings,
            developmentTeamId: developmentTeamId,
            automaticSigning: automaticSigning
        )

        return Project(
            name: projectName,
            targets: [appTarget]
        )
    }

    /// Creates a standalone app extension project linked to a composition root.
    ///
    /// The extension bundle identifier is derived from `hostBundleId` and `name`.
    public static func makeAppExtensionProject(
        name: String,
        hostBundleId: String,
        destinations: Destinations,
        product: Product,
        compositionRoot: CompositionRoot,
        capabilities: [Capability] = [],
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = nil,
        infoPlist: InfoPlist = .extendingDefault(with: [:]),
        additionalSettings: SettingsDictionary = [:],
        developmentTeamId: String? = nil,
        extensionPointIdentifier: String = "com.apple.widgetkit-extension"
    ) -> Project {
        let entitlements = EntitlementsFactory.make(
            hostBundleId: hostBundleId,
            destinations: destinations,
            capabilities: capabilities
        )
        let target = TargetFactory.makeExtension(
            name: name,
            hostBundleId: hostBundleId,
            destinations: destinations,
            product: product,
            infoPlist: infoPlist,
            entitlements: entitlements,
            sources: sources,
            resources: resources,
            dependencies: [compositionRoot.dependency],
            additionalSettings: additionalSettings,
            developmentTeamId: developmentTeamId,
            extensionPointIdentifier: extensionPointIdentifier
        )

        return Project(
            name: name,
            targets: [target]
        )
    }

    /// Creates a composition root project.
    ///
    /// Composition roots are the only place where it's acceptable to depend on other modules'
    /// implementation targets directly.
    public static func makeCompositionRoot(
        module: CompositionRoot,
        destinations: Destinations = .iOS,
        product: Product = .staticFramework,
        dependencies: [CompositionRootDependency],
        additionalSettings: SettingsDictionary = [:],
        tags: [Tag] = []
    ) -> Project {
        let target = TargetFactory.makeImpl(
            module: module.id,
            destinations: destinations,
            product: product,
            dependencies: dependencies.flatMap(\.targets),
            resources: nil,
            additionalSettings: additionalSettings,
            tags: tags
        )

        let scheme = Scheme.scheme(
            name: module.id.name,
            shared: true,
            buildAction: .buildAction(targets: [.target(target.name)])
        )

        return Project(
            name: module.id.name,
            targets: [target],
            schemes: [scheme]
        )
    }

    /// Creates an app project with optional inline extension targets.
    ///
    /// Prefer `makeHostApp` when using composition roots and the capabilities DSL.
    public static func makeApp(
        projectName: String,
        appName: String? = nil,
        bundleId: String,
        destinations: Destinations,
        deploymentTargets: DeploymentTargets? = nil,
        sources: SourceFilesList = ["Sources/**"],
        resources: ResourceFileElements? = ["Resources/**"],
        infoPlist: InfoPlist = .default,
        dependencies: [TargetDependency] = [],
        settings: SettingsDictionary = [:],
        developmentTeamId: String? = nil,
        automaticSigning: Bool = true,
        extensions: [ExtensionSpec] = []
    ) -> Project {
        let appTargetName = appName ?? projectName

        let resolvedDeploymentTargets: DeploymentTargets = deploymentTargets ?? {
            let platforms = destinations.platforms
            return .multiplatform(
                iOS: platforms.contains(.iOS) ? "16.0" : nil,
                macOS: platforms.contains(.macOS) ? "13.0" : nil,
                watchOS: nil,
                tvOS: nil,
                visionOS: nil
            )
        }()

        let hostBundleId = bundleId

        let extensionTargets: [Target] = extensions.map { spec in
            TargetFactory.makeExtension(
                name: spec.name,
                hostBundleId: hostBundleId,
                destinations: destinations,
                product: spec.product,
                infoPlist: spec.infoPlist,
                entitlements: nil,
                sources: spec.sources,
                resources: spec.resources,
                dependencies: spec.dependencies,
                additionalSettings: spec.settings,
                developmentTeamId: developmentTeamId,
                extensionPointIdentifier: spec.extensionPointIdentifier
            )
        }

        let allDependencies = dependencies + extensionTargets.map { .target(name: $0.name) }
        let appTarget = TargetFactory.makeApp(
            name: appTargetName,
            destinations: destinations,
            bundleId: hostBundleId,
            deploymentTargets: resolvedDeploymentTargets,
            entitlements: nil,
            infoPlist: infoPlist,
            sources: sources,
            resources: resources,
            dependencies: allDependencies,
            additionalSettings: settings,
            developmentTeamId: developmentTeamId,
            automaticSigning: automaticSigning
        )

        return Project(
            name: projectName,
            targets: [appTarget] + extensionTargets
        )
    }

    /// Creates a standard feature module project (Interface + Impl + Testing + Tests).
    ///
    /// This factory also enforces external dependency rules for the feature's layer.
    public static func makeFeature(
        module: ModuleID,
        destinations: Destinations = .iOS,
        product: Product = .framework,
        dependencies: [Dependency],
        testDependencies: [Dependency] = [],
        hasResources: Bool = false,
        additionalSettings: SettingsDictionary = [:],
        tags: [Tag] = []
    ) -> Project {
        validateExternalDependenciesAllowed(module: module, dependencies: dependencies, context: "makeFeature(dependencies:)")
        validateExternalDependenciesAllowed(module: module, dependencies: testDependencies, context: "makeFeature(testDependencies:)")

        let interface = TargetFactory.makeInterface(
            module: module,
            destinations: destinations,
            dependencies: []
        )
        validateNoExternalDependencies(module: module, target: interface)

        let implDeps: [TargetDependency] = [.target(name: interface.name)] + dependencies.map(\.target)
        let impl = TargetFactory.makeImpl(
            module: module,
            destinations: destinations,
            product: product,
            dependencies: implDeps,
            resources: hasResources ? ["Resources/**"] : nil,
            additionalSettings: additionalSettings,
            tags: tags
        )

        let testing = TargetFactory.makeTesting(
            module: module,
            destinations: destinations,
            dependencies: [.target(name: interface.name)]
        )

        let testDeps: [TargetDependency] = [.target(name: impl.name), .target(name: testing.name)] + testDependencies.map(\.target)
        let tests = TargetFactory.makeTests(
            module: module,
            destinations: destinations,
            dependencies: testDeps,
            tags: tags
        )

        let scheme = Scheme.scheme(
            name: module.name,
            shared: true,
            buildAction: .buildAction(targets: [.target(impl.name)]),
            testAction: .targets([.testableTarget(target: .target(tests.name))], configuration: .debug)
        )

        return Project(
            name: module.name,
            targets: [interface, impl, testing, tests],
            schemes: [scheme]
        )
    }

    /// Enforces the rule that Interface targets must not link external dependencies.
    private static func validateNoExternalDependencies(module: ModuleID, target: Target) {
        let externals = target.dependencies.compactMap { dependency -> String? in
            if case let .external(name, _) = dependency { return name }
            return nil
        }
        guard externals.isEmpty else {
            fatalError(
                """
                🛑 ARCHITECTURE VIOLATION 🛑
                ---------------------------------------------------
                Module: \(module.name) (Layer: \(module.layer))
                Target: \(target.name)
                Rule: Target must not link external libraries.
                External dependencies: \(externals.sorted())
                ---------------------------------------------------
                """
            )
        }
    }

    /// Enforces allow-listed external dependencies per module layer.
    private static func validateExternalDependenciesAllowed(module: ModuleID, dependencies: [Dependency], context: String) {
        let forbidden = dependencies.compactMap { dependency -> Dependency.ExternalDependencyMetadata? in
            guard let external = dependency.externalDependency else { return nil }
            return external.allowedLayers.contains(module.layer) ? nil : external
        }

        guard forbidden.isEmpty else {
            let unique = Array(Set(forbidden.map(\.name))).sorted()
            fatalError(
                """
                🛑 ARCHITECTURE VIOLATION 🛑
                ---------------------------------------------------
                Module: \(module.name) (Layer: \(module.layer))
                Context: \(context)
                Forbidden external dependencies: \(unique)

                Fix:
                - Move usage behind a Core wrapper, or
                - Update the project's allow-list for the library.
                ---------------------------------------------------
                """
            )
        }
    }
}
