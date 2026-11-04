require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/managers/DownloadManager.swift'))
initializer = source[/    init\(\) \{.*?(?=    private func startMonitoringIfNeeded)/m]
subscription = source[/    private var settingsSubscription: AnyCancellable\?/]
abort 'Download initializer not found' unless initializer

fixture = <<~'SWIFT'
  import Foundation
  import Combine
  enum Key { case enableDownloadListener }
  enum Defaults {
      static let changes = PassthroughSubject<Void, Never>()
      static func publisher(_ key: Key, options: Set<Int> = []) -> PassthroughSubject<Void, Never> { changes }
      static subscript(_ key: Key) -> Bool { false }
  }
  @MainActor final class DownloadManager {
      var updates = 0
      private func startMonitoringIfNeeded() { updates += 1 }
      private func requestDownloadsPermissionIfNeeded() {}
SWIFT
checks = <<~'SWIFT'
  @main struct Test {
      @MainActor static func main() async throws {
          let manager = DownloadManager()
          let initial = manager.updates
          Defaults.changes.send(())
          try await Task.sleep(for: .milliseconds(30))
          assert(manager.updates == initial + 1, "Enabling Downloads must reach the running monitor")
          Defaults.changes.send(())
          try await Task.sleep(for: .milliseconds(30))
          assert(manager.updates == initial + 2, "Disabling Downloads must also reach the running monitor")
          print("PASS: Downloads keeps observing Settings after initialization")
      }
  }
SWIFT

Dir.mktmpdir('atoll-download-settings') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'download-settings-tests')
  File.write(swift, fixture + subscription.to_s + "\n" + initializer + "\n}\n" + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', '-parse-as-library', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.first(6)
  exit(status.success? ? 0 : 1)
end
