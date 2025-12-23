@preconcurrency import ProjectDescription
@preconcurrency import ProjectInfraPlugin
@preconcurrency import ProjectDescriptionHelpers

let module = ModuleID.feature(.auth)

let project = ProjectFactory.makeFeature(
    module: module,
    destinations: Destinations.iOS.union(Destinations.macOS),
    product: .framework,
    dependencies: [
        .external(dependency: .algorithms),
//         Example: .interface(.core(.networking))
    ],
    testDependencies: [
        // Example: .testing(.core(.networking))
    ]
)
