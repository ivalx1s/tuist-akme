import ProjectDescription
import ProjectInfraPlugin
import ProjectDescriptionHelpers

let developmentTeamId = Environment.developmentTeamId.getString(default: "")
let projectName = Environment.iosAppProjectName.getString(default: "iOSApp")
let appName = Environment.iosAppName.getString(default: "AcmeApp")
let iosMinVersion = Environment.iosMinVersion.getString(default: "16.0")

let project = ProjectFactory.makeHostApp(
    projectName: projectName,
    appName: appName,
    bundleId: AppIdentifiers.iOSApp.bundleId,
    destinations: .iOS,
    deploymentTargets: .iOS(iosMinVersion),
    sources: ["Sources/**"],
    resources: ["Resources/**"],
    infoPlist: .extendingDefault(with: [
        "UILaunchScreen": [:],
    ]),
    compositionRoot: .app,
    embeddedExtensions: [
        AppProjects.iOS.acmeWidget,
    ],
    capabilities: .iOSPlusAppex + [
        .iCloudCloudKitContainer(container: .shared),
    ],
    developmentTeamId: developmentTeamId
)
