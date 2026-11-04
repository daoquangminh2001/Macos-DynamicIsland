import SwiftUI
import Defaults

struct LocalQuickActionsMenu: View {
    @EnvironmentObject private var vm: DynamicIslandViewModel
    @ObservedObject private var caffeinate = CaffeinateManager.shared
    @ObservedObject private var timer = TimerManager.shared
    @Default(.enableCaffeinate) private var enableCaffeinate
    @Default(.showCaffeinateIcon) private var showCaffeinateIcon
    @Default(.enableTimerFeature) private var enableTimerFeature
    @Default(.enableClipboardManager) private var enableClipboardManager
    @Default(.showClipboardIcon) private var showClipboardIcon
    @Default(.enableColorPickerFeature) private var enableColorPickerFeature
    @Default(.showColorPickerIcon) private var showColorPickerIcon
    @State private var showClipboardPopover = false
    @State private var showColorPickerPopover = false

    var body: some View {
        Button(action: LocalScreenLock.lock) {
            actionIcon("lock")
        }
        .buttonStyle(.plain)
        .help("Khóa màn hình")
        .accessibilityLabel("Khóa màn hình")

        if enableClipboardManager && showClipboardIcon {
            Button {
                if Defaults[.clipboardDisplayMode] == .popover {
                    showClipboardPopover.toggle()
                } else {
                    // Tab layouts are unavailable in Minimalistic UI.
                    ClipboardPanelManager.shared.toggleClipboardPanel()
                }
            } label: {
                actionIcon("list.clipboard")
            }
            .buttonStyle(.plain)
            .help("Clipboard")
            .accessibilityLabel("Clipboard")
            .popover(isPresented: $showClipboardPopover, arrowEdge: .bottom) {
                ClipboardPopover()
            }
            .onChange(of: showClipboardPopover) { _, active in
                vm.isClipboardPopoverActive = active
                if !active { vm.shouldRecheckHover.toggle() }
            }
            .onDisappear { vm.isClipboardPopoverActive = false }
        }

        if enableColorPickerFeature && showColorPickerIcon {
            Button {
                if Defaults[.colorPickerDisplayMode] == .popover {
                    showColorPickerPopover.toggle()
                } else {
                    ColorPickerPanelManager.shared.toggleColorPickerPanel()
                }
            } label: {
                actionIcon("eyedropper")
            }
            .buttonStyle(.plain)
            .help("Chọn màu")
            .accessibilityLabel("Chọn màu")
            .popover(isPresented: $showColorPickerPopover, arrowEdge: .bottom) {
                ColorPickerPopover()
            }
            .onChange(of: showColorPickerPopover) { _, active in
                vm.isColorPickerPopoverActive = active
                if !active { vm.shouldRecheckHover.toggle() }
            }
            .onDisappear { vm.isColorPickerPopoverActive = false }
        }

        if enableCaffeinate && showCaffeinateIcon {
            Menu {
                Button("30 phút") { keepAwake(.thirtyMinutes) }
                Button("1 giờ") { keepAwake(.oneHour) }
                Button("Đến khi tắt thủ công") { keepAwake(.indefinite) }
                if caffeinate.isActive {
                    Divider()
                    Button("Tắt giữ máy thức") { caffeinate.deactivate() }
                }
            } label: {
                actionIcon(caffeinate.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .foregroundStyle(caffeinate.isActive ? Color.yellow : Color.white)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(caffeinate.isActive ? "Giữ máy thức • Đang bật" : "Giữ máy thức")
            .accessibilityLabel("Giữ máy thức")
        }

        if enableTimerFeature {
            Menu {
                ForEach([5, 15, 25, 60], id: \.self) { minutes in
                    Button("\(minutes) phút") {
                        timer.startTimer(duration: TimeInterval(minutes * 60), name: "\(minutes) phút")
                    }
                    .disabled(timer.isTimerActive)
                }
                if timer.isTimerActive {
                    Divider()
                    Button(timer.isPaused ? "Tiếp tục hẹn giờ" : "Tạm dừng hẹn giờ") {
                        if timer.isPaused { timer.resumeTimer() } else { timer.pauseTimer() }
                    }
                    Button("Dừng hẹn giờ") { timer.stopTimer() }
                }
            } label: {
                actionIcon(timer.isTimerActive ? "timer.circle.fill" : "timer")
                    .foregroundStyle(timer.isTimerActive ? Color.orange : Color.white)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Hẹn giờ")
            .accessibilityLabel("Hẹn giờ")
        }

        LocalUtilitiesMenu()

        Button {
            SettingsWindowController.shared.showWindow()
        } label: {
            actionIcon("gearshape")
        }
        .buttonStyle(.plain)
        .help("Cài đặt")
        .accessibilityLabel("Cài đặt")
    }

    private func actionIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .medium))
            .frame(width: 28, height: 28)
            .background(.white.opacity(0.07), in: Circle())
            .contentShape(Circle())
    }

    private func keepAwake(_ duration: CaffeinateDuration) {
        caffeinate.activate(for: duration)
    }

}

/// Gives compact mode access to the same built-in utility views as the tabs.
struct LocalUtilitiesMenu: View {
    @EnvironmentObject private var vm: DynamicIslandViewModel
    @ObservedObject private var coordinator = DynamicIslandViewCoordinator.shared
    @Default(.enableNotes) private var enableNotes
    @Default(.dynamicShelf) private var dynamicShelf
    @Default(.enableStatsFeature) private var enableStatsFeature
    @Default(.enableTerminalFeature) private var enableTerminalFeature
    @Default(.enableTimerFeature) private var enableTimerFeature
    @Default(.showCalendar) private var showCalendar
    @Default(.showMirror) private var showMirror
    @Default(.enableClipboardManager) private var enableClipboardManager
    @Default(.enableColorPickerFeature) private var enableColorPickerFeature
    @Default(.enableCaffeinate) private var enableCaffeinate
    @ObservedObject private var caffeinate = CaffeinateManager.shared
    @State private var preview: Preview?
    @State private var previewToken = UUID()

    private enum Preview: String, Identifiable {
        case utilities, calendar, mirror
        var id: String { rawValue }
    }

    private var availableViews: [NotchViews] {
        var views: [NotchViews] = [.home]
        if enableNotes { views.append(.notes) }
        if dynamicShelf { views.append(.shelf) }
        if enableStatsFeature { views.append(.stats) }
        if enableTerminalFeature { views.append(.terminal) }
        if enableTimerFeature { views.append(.timer) }
        return views
    }

    var body: some View {
        Button {
            preview = preview == nil ? .utilities : nil
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help("Tiện ích")
        .accessibilityLabel("Tiện ích")
        .popover(item: $preview, arrowEdge: .bottom) { item in
            Group {
                switch item {
                case .utilities:
                    ScrollView {
                        utilityOptions
                            .padding(8)
                    }
                    .frame(width: 250, height: 340)
                case .calendar:
                    StandaloneCalendarView()
                        .frame(width: 500, height: 200)
                        .padding(12)
                case .mirror:
                    CameraPreviewView(webcamManager: vm.webcamManager)
                        .frame(width: 360, height: 220)
                        .padding(12)
                        .onDisappear {
                            vm.webcamManager.stopSession()
                            vm.isCameraExpanded = false
                        }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: preview) { _, item in
            if item != nil { AppDelegate.shared?.cancelPendingNotchAutoClose() }
            vm.setAutoCloseSuppression(item != nil, token: previewToken)
            if item == nil { vm.shouldRecheckHover.toggle() }
        }
        .onChange(of: availableViews) { _, views in
            if !views.contains(coordinator.currentView) { open(.home) }
        }
        .onChange(of: showCalendar) { _, enabled in
            if !enabled && preview == .calendar { preview = nil }
        }
        .onChange(of: showMirror) { _, enabled in
            if !enabled && preview == .mirror { preview = nil }
        }
        .onDisappear { vm.setAutoCloseSuppression(false, token: previewToken) }
    }

    private var utilityOptions: some View {
        VStack(alignment: .leading, spacing: 2) {
            if coordinator.currentView != .home {
                utilityAction("Trang chính", icon: "house") { open(.home) }
            }
            if enableClipboardManager {
                utilityAction("Clipboard", icon: "list.clipboard") {
                    preview = nil
                    ClipboardPanelManager.shared.toggleClipboardPanel()
                }
            }
            if enableColorPickerFeature {
                utilityAction("Chọn màu", icon: "eyedropper") {
                    preview = nil
                    ColorPickerPanelManager.shared.toggleColorPickerPanel()
                }
            }
            if enableCaffeinate {
                utilityAction(caffeinate.isActive ? "Tắt giữ máy thức" : "Giữ máy thức (30 phút)", icon: "cup.and.saucer") {
                    if caffeinate.isActive { caffeinate.deactivate() }
                    else { caffeinate.activate(for: .thirtyMinutes) }
                }
            }
            if showCalendar {
                utilityAction("Lịch", icon: "calendar") { preview = .calendar }
            }
            if showMirror {
                utilityAction("Gương camera", icon: "web.camera") {
                    if !vm.webcamManager.isSessionRunning { vm.toggleCameraPreview() }
                    preview = .mirror
                }
            }
            if enableNotes { utilityAction("Ghi chú", icon: "note.text") { open(.notes) } }
            if dynamicShelf { utilityAction("Kệ tệp", icon: "tray") { open(.shelf) } }
            if enableStatsFeature { utilityAction("Thống kê hệ thống", icon: "chart.xyaxis.line") { open(.stats) } }
            if enableTimerFeature { utilityAction("Hẹn giờ", icon: "timer") { open(.timer) } }
            if enableTerminalFeature { utilityAction("Terminal", icon: "apple.terminal") { open(.terminal) } }
            Divider()
            utilityAction("Cài đặt", icon: "gearshape") {
                preview = nil
                SettingsWindowController.shared.showWindow()
            }
        }
    }

    private func utilityAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ view: NotchViews) {
        preview = nil
        AppDelegate.shared?.cancelPendingNotchAutoClose()
        coordinator.currentView = view
        vm.open()
        if view == .home {
            vm.finishUtilityNavigation()
        } else {
            vm.beginUtilityNavigation()
        }
    }
}

enum LocalScreenLock {
    static func lock() {
        guard let library = dlopen("/System/Library/PrivateFrameworks/login.framework/login", RTLD_LAZY) else {
            showLockError()
            return
        }
        defer { dlclose(library) }
        guard let symbol = dlsym(library, "SACLockScreenImmediate") else {
            showLockError()
            return
        }
        unsafeBitCast(symbol, to: (@convention(c) () -> Void).self)()
    }

    private static func showLockError() {
        let alert = NSAlert()
        alert.messageText = "Không thể khóa màn hình"
        alert.informativeText = "Bạn có thể dùng phím Control–Command–Q của macOS."
        alert.runModal()
    }
}
