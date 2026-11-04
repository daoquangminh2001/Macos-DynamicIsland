require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/models/DynamicIslandViewModel.swift'))
state = source[/    @Published private\(set\) var isAutoCloseSuppressed.*?(?=    private let clipboardFocusWindow)/m]
methods = source[/    func setAutoCloseSuppression\(.*?(?=    private func focusClipboardTabIfNeeded)/m]
abort 'Utility navigation state not found' unless state && methods
coordinator = File.read(File.join(root, 'DynamicIsland/DynamicIslandViewCoordinator.swift'))
allowed_views = coordinator[/    static func allowsMinimalisticView\(.*?(?=\n    \/\/\/ Direction)/m]
views = File.read(File.join(root, 'DynamicIsland/enums/generic.swift'))[/enum NotchViews[^}]*}/m]
abort 'Minimalistic utility routing policy not found' unless allowed_views && views

checks = <<~'SWIFT'
  @main struct Tests {
      @MainActor static func main() {
          for view in [NotchViews.notes, .shelf, .stats, .timer, .terminal, .clipboard, .colorPicker] {
              assert(Fixture.allowsMinimalisticView(view, localBuild: true), "Local compact mode must allow utility navigation")
              assert(!Fixture.allowsMinimalisticView(view, localBuild: false), "Keep upstream compact behavior")
          }
          assert(Fixture.allowsMinimalisticView(.home, localBuild: false))
          assert(!Fixture.allowsMinimalisticView(.llmUsage, localBuild: true))
          assert(!Fixture.allowsMinimalisticView(.extensionExperience, localBuild: true))
          let vm = Fixture()
          vm.beginUtilityNavigation()
          assert(vm.isUtilityNavigationPending && vm.isAutoCloseSuppressed,
                 "Selecting a utility must survive menu dismissal outside the notch")
          vm.finishUtilityNavigation()
          assert(!vm.isUtilityNavigationPending && !vm.isAutoCloseSuppressed,
                 "Entering the utility must restore ordinary hover behavior")
          let popover = UUID()
          vm.setAutoCloseSuppression(true, token: popover)
          vm.beginUtilityNavigation()
          vm.finishUtilityNavigation()
          assert(vm.isAutoCloseSuppressed, "Finishing navigation must preserve another presenter's suppression")
          vm.setAutoCloseSuppression(false, token: popover)
          assert(!vm.isAutoCloseSuppressed)
          print("PASS: utility navigation stays open until hover; other popover tokens preserved")
      }
  }
SWIFT
Dir.mktmpdir('atoll-utility-navigation') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'navigation-tests')
  File.write(swift, "import Foundation\nimport Combine\n" + views + "\n@MainActor final class Fixture {\n" + state + methods + allowed_views + "\n}\n" + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', '-parse-as-library', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.first(5)
  exit(status.success? ? 0 : 1)
end
