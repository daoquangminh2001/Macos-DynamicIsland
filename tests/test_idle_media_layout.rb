# Run the production sizing function without launching Atoll or accessing user data.
require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/sizing/matters.swift'))
layout = source[/private let minimalisticBaseOpenNotchSize:.*?(?=let cornerRadiusInsets:)/m]
abort 'Could not locate production minimalistic layout' unless layout

fixture = <<~SWIFT
  import Foundation
  enum Key { case enableSystemHUD, enableMinimalisticUI, enableLyrics, showStandardMediaControls, autoHideInactiveNotchMediaPlayer }
  enum Defaults {
      static var values: [Key: Bool] = [:]
      static subscript(key: Key) -> Bool { values[key] ?? false }
  }
  var cameraReserve: CGFloat = 38
  var openNotchSize = CGSize(width: 640, height: 200)
  func minimalisticCameraReservedHeight() -> CGFloat { cameraReserve }
  final class MusicManager {
      static let shared = MusicManager()
      var hasActiveSession = false
      var isAdvertisement = false
  }
  final class ReminderLiveActivityManager {
      static let shared = ReminderLiveActivityManager()
      var activeWindowReminders: [Int] = []
      static func additionalHeight(forRowCount count: Int) -> CGFloat { CGFloat(count * 30) }
  }
  enum SneakType { case volume, brightness, backlight, music }
  enum NotchViews { case home, notes, shelf, stats, terminal, timer }
  struct SneakSnapshot { var show = false; var type = SneakType.music }
  final class DynamicIslandViewCoordinator {
      static let shared = DynamicIslandViewCoordinator()
      var sneakPeek = SneakSnapshot()
      var timerLiveActivityEnabled = false
      var currentView = NotchViews.home
  }
  final class TimerManager {
      static let shared = TimerManager()
      var isExternalTimerActive = false
  }
SWIFT

checks = <<~SWIFT
  Defaults.values = [.enableMinimalisticUI: true, .showStandardMediaControls: true, .autoHideInactiveNotchMediaPlayer: true, .enableLyrics: true]
  for pill in [false, true] {
      cameraReserve = pill ? 0 : 38
      let idle = minimalisticOpenNotchSize(isDynamicIslandMode: pill)
      assert(idle.height == cameraReserve + 32, "Idle home must reserve room for quick actions, got \\(idle.height)")
      assert(idle.width == 330, "Idle icon toolbar must stay compact")
      MusicManager.shared.hasActiveSession = true
      assert(minimalisticOpenNotchSize(isDynamicIslandMode: pill).height == (pill ? 194 : 230))
      MusicManager.shared.hasActiveSession = false
  }
  Defaults.values[.autoHideInactiveNotchMediaPlayer] = false
  assert(minimalisticOpenNotchSize(isDynamicIslandMode: false).height == 180, "Explicit empty player must remain available without lyric space")
  Defaults.values[.showStandardMediaControls] = false
  assert(minimalisticOpenNotchSize(isDynamicIslandMode: false).height == cameraReserve + 32, "Disabled media must leave quick actions available")
  ReminderLiveActivityManager.shared.activeWindowReminders = [1, 2]
  DynamicIslandViewCoordinator.shared.timerLiveActivityEnabled = true
  TimerManager.shared.isExternalTimerActive = true
  assert(minimalisticOpenNotchSize(isDynamicIslandMode: false).height == 214, "Timers and reminders must survive idle media")
  cameraReserve = 38
  Defaults.values[.enableSystemHUD] = true
  DynamicIslandViewCoordinator.shared.sneakPeek.show = true
  for kind in [SneakType.volume, .brightness, .backlight] {
      DynamicIslandViewCoordinator.shared.sneakPeek.type = kind
      assert(minimalisticSystemHUDVisible())
      let hud = minimalisticOpenNotchSize(isDynamicIslandMode: false)
      assert(hud.width == 330 && hud.height == cameraReserve + 32, "System HUD must have its own readable surface")
  }
  DynamicIslandViewCoordinator.shared.sneakPeek.type = .music
  assert(!minimalisticSystemHUDVisible(), "Music must preserve its existing layout")
  DynamicIslandViewCoordinator.shared.sneakPeek.show = false
  for utility in [NotchViews.notes, .shelf, .stats, .terminal, .timer] {
      DynamicIslandViewCoordinator.shared.currentView = utility
      assert(!minimalisticQuickActionsOnly(), "A utility must not be clipped into the idle toolbar")
      let size = minimalisticOpenNotchSize(isDynamicIslandMode: false)
      assert(size.width == 640 && size.height == 238, "Utility content needs standard width and camera clearance")
  }
  DynamicIslandViewCoordinator.shared.currentView = .home
  print("PASS: idle/active, notch/pill, lyrics, manual empty state, disabled controls, timers and reminders")
SWIFT

Dir.mktmpdir('atoll-idle-layout') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'layout-tests')
  File.write(swift, fixture + layout + "\n@main struct Tests { @MainActor static func main() {\n" + checks + "\n} }\n")
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', '-parse-as-library', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.first(8)
  exit(status.success? ? 0 : 1)
end
