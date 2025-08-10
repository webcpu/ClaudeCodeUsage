import Foundation

// MARK: - Feature Flags

/// Centralized feature flags for gradual rollout of new features
public struct FeatureFlags {
    /// Whether to use the new actor-based LiveMonitor implementation
    public static var useActorBasedLiveMonitor: Bool {
        get {
            UserDefaults.standard.bool(forKey: "FeatureFlag.UseActorBasedLiveMonitor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "FeatureFlag.UseActorBasedLiveMonitor")
        }
    }
    
    /// Enable feature flag based on percentage rollout
    public static func enableActorBasedLiveMonitor(percentage: Int) {
        let userHash = getUserHash()
        let shouldEnable = (userHash % 100) < percentage
        useActorBasedLiveMonitor = shouldEnable
    }
    
    private static func getUserHash() -> Int {
        // Get or create a stable user identifier
        let key = "UserIdentifier"
        if let identifier = UserDefaults.standard.string(forKey: key) {
            return abs(identifier.hashValue)
        } else {
            let newIdentifier = UUID().uuidString
            UserDefaults.standard.set(newIdentifier, forKey: key)
            return abs(newIdentifier.hashValue)
        }
    }
    
    /// Reset all feature flags to defaults
    public static func reset() {
        UserDefaults.standard.removeObject(forKey: "FeatureFlag.UseActorBasedLiveMonitor")
    }
}

// MARK: - Development Mode

#if DEBUG
extension FeatureFlags {
    /// Force enable all experimental features in debug mode
    public static func enableAllExperimentalFeatures() {
        useActorBasedLiveMonitor = true
    }
    
    /// Force disable all experimental features in debug mode
    public static func disableAllExperimentalFeatures() {
        useActorBasedLiveMonitor = false
    }
}
#endif