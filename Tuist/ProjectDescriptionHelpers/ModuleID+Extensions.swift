import ProjectDescription
import ProjectInfraPlugin

public extension ModuleID {
    static func feature(_ module: FeatureLayer) -> ModuleID {
        ModuleID(.feature, module.rawValue)
    }

    static func core(_ module: CoreLayer) -> ModuleID {
        ModuleID(.core, module.rawValue)
    }

    static func shared(_ module: SharedLayer) -> ModuleID {
        ModuleID(.shared, module.rawValue)
    }

    static func utility(_ module: UtilityLayer) -> ModuleID {
        ModuleID(.utility, module.rawValue)
    }
}
