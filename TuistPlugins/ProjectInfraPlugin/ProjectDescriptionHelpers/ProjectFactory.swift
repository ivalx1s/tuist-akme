import ProjectDescription

public enum ProjectFactory {
    public static func makeFeature(
        module: ModuleID,
        destinations: Destinations = .iOS,
        product: Product = .framework,
        dependencies: [Dependency],
        testDependencies: [Dependency] = [],
        hasResources: Bool = false,
        additionalSettings: SettingsDictionary = [:]
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
            additionalSettings: additionalSettings
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
            dependencies: testDeps
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
