import ProjectDescription

let workspace = Workspace(
    name: Environment.workspaceName.getString(default: "AcmeApp"),
    projects: [
        "Apps/**",
        "Modules/**",
    ]
)
