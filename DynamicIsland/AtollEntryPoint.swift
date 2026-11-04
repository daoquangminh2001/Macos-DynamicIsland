import Foundation
import Darwin

@main
enum AtollEntryPoint {
    static func configureLocalPreferences(_ defaults: UserDefaults, domainName: String) {
        // Local utilities are opt-in defaults, not runtime locks. Seed only
        // missing values so a Settings change survives the next launch.
        let localUtilities = ["enableClipboardManager", "persistClipboardHistory", "enableDownloadListener", "enableTerminalFeature"]
        let saved = defaults.persistentDomain(forName: domainName) ?? [:]
        for key in localUtilities where saved[key] == nil {
            defaults.set(false, forKey: key)
        }

        let disabled = ["enableLLMUsageFeature", "enableClaudeProvider", "enableCodexProvider",
            "enableCursorProvider", "enableAntigravityProvider", "enableNewAPIProvider",
            "enableScreenAssistant", "enableScreenRecordingDetection",
            "enableThirdPartyExtensions", "enableExtensionFileSharing",
            "enableLockScreenWeatherWidget", "enableLyrics", "SUEnableAutomaticChecks",
            "SUAutomaticallyUpdate", "SUSendProfileInfo"]
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        for key in localUtilities { arguments.removeValue(forKey: key) }
        for key in disabled { arguments[key] = false }
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }

    static func main() {
        if Bundle.main.object(forInfoDictionaryKey: "AtollLocalOfflineBuild") as? Bool == true {
            do {
                guard let url = Bundle.main.url(forResource: "offline", withExtension: "sb") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                let home = FileManager.default.homeDirectoryForCurrentUser.resolvingSymlinksInPath().path
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let profile = try String(contentsOf: url, encoding: .utf8)
                    .replacingOccurrences(of: "(param \"USER_HOME\")", with: "\"\(home)\"")
                guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sandbox_init") else {
                    throw CocoaError(.executableNotLoadable)
                }
                let initialize = unsafeBitCast(symbol, to: (@convention(c) (UnsafePointer<CChar>, UInt64, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Int32).self)
                var error: UnsafeMutablePointer<CChar>?
                guard profile.withCString({ initialize($0, 0, &error) }) == 0 else {
                    fputs("Cannot apply Atoll offline profile\n", stderr)
                    exit(1)
                }
                configureLocalPreferences(.standard, domainName: Bundle.main.bundleIdentifier!)
            } catch {
                fputs("Cannot load Atoll offline profile\n", stderr)
                exit(1)
            }
        }
        DynamicNotchApp.main()
    }
}
