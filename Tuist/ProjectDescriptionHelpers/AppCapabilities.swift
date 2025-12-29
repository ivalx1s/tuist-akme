import ProjectInfraPlugin



/// Canonical capability definitions shared across the host app and its extensions.
///
/// Keep this centralized so app extensions can "inherit" capabilities without duplicating
/// identifier logic across multiple `Project.swift` manifests.
extension [Capability] {
    /// Capabilities shared by the iOS host app and its app extensions.
    public static let iOSPlusAppex: [Capability] = [
        .appGroups(),
        .iCloud(services: [.cloudKit]),
        .keychainSharing(),
        .keychainSharing(group: .custom(id: "testKeychainGroupId")),
        .applePayMerchant(),
        .iCloudUbiquityContainer(),
        .nfcTagReading(formats: [.tag]),
        .wiFiAware([Capability.WiFiAwareRole.publish, .subscribe]),
        .healthKit([.backgroundDelivery]),
//        .portal(.appAttest, environment: .development),
        
//        .iCloudCloudKitContainer()
    ]
}
