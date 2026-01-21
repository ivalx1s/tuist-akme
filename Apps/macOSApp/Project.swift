import ProjectDescription
import ProjectInfraPlugin
import ProjectDescriptionHelpers

let developmentTeamId = Environment.developmentTeamId.getString(default: "")
let projectName = Environment.macosAppProjectName.getString(default: "macOSApp")
let appName = Environment.macosAppName.getString(default: "AcmeMacApp")
let macosMinVersion = Environment.macosMinVersion.getString(default: "13.0")

let project = ProjectFactory.makeHostApp(
    projectName: projectName,
    appName: appName,
    bundleId: AppIdentifiers.macOSApp.bundleId,
    destinations: .macOS,
    deploymentTargets: .macOS(macosMinVersion),
    sources: ["Sources/**"],
    resources: ["Resources/**"],
    compositionRoot: .app,
    capabilities: [
        .iCloudCloudKitContainer(),
        .iCloudCloudKitContainer(container: .shared)
    ],
    developmentTeamId: developmentTeamId,
    automaticSigning: true
)
