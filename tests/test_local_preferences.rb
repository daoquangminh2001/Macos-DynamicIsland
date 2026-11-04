require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/AtollEntryPoint.swift'))
policy = source[/    static func configureLocalPreferences\(.*?(?=\n    static func main\()/m]
abort 'Local utility preferences are still forced off by the startup policy' unless policy

checks = <<~'SWIFT'
  let domain = "local.atoll.preference-tests.\(ProcessInfo.processInfo.globallyUniqueString)"
  let defaults = UserDefaults(suiteName: domain)!
  defer { defaults.removePersistentDomain(forName: domain) }
  Policy.configureLocalPreferences(defaults, domainName: domain)
  for key in ["enableClipboardManager", "persistClipboardHistory", "enableDownloadListener", "enableTerminalFeature"] {
      assert(!defaults.bool(forKey: key), "Local utilities must start off")
      defaults.set(true, forKey: key)
      assert(defaults.bool(forKey: key), "User must be able to enable \(key)")
  }
  defaults.set(true, forKey: "enableScreenAssistant")
  defaults.set(true, forKey: "enableCodexProvider")
  Policy.configureLocalPreferences(defaults, domainName: domain)
  for key in ["enableClipboardManager", "persistClipboardHistory", "enableDownloadListener", "enableTerminalFeature"] {
      assert(defaults.bool(forKey: key), "Startup must preserve user's enabled \(key)")
      defaults.set(false, forKey: key)
  }
  Policy.configureLocalPreferences(defaults, domainName: domain)
  assert(!defaults.bool(forKey: "enableClipboardManager"))
  assert(!defaults.bool(forKey: "persistClipboardHistory"))
  assert(!defaults.bool(forKey: "enableDownloadListener"))
  assert(!defaults.bool(forKey: "enableTerminalFeature"))
  assert(!defaults.bool(forKey: "enableScreenAssistant"), "Network features remain unavailable offline")
  assert(!defaults.bool(forKey: "enableCodexProvider"), "Credential providers must remain off")
  print("PASS: local utility enable/disable persists; defaults off; offline restrictions preserved")
SWIFT

Dir.mktmpdir('atoll-local-preferences') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'preference-tests')
  File.write(swift, "import Foundation\nenum Policy {\n" + policy + "\n}\n" + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output
  exit(status.success? ? 0 : 1)
end
