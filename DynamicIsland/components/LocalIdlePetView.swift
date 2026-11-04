import SwiftUI
import Defaults

struct LocalIdleHomeView: View {
    @Default(.enableLocalIdlePet) private var enablePet
    @Default(.enableCaffeinate) private var enableCaffeinate
    @ObservedObject private var caffeinate = CaffeinateManager.shared
    @ObservedObject private var battery = BatteryStatusViewModel.shared

    var body: some View {
        HStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeline.date, format: .dateTime.hour().minute())
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(timeline.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 120, alignment: .leading)
            .accessibilityElement(children: .combine)

            if enablePet {
                LocalIdlePetView()
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Trạng thái")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 0)
                    LocalUtilitiesMenu()
                }
                Label("Pin \(Int(battery.levelBattery))%", systemImage: battery.isCharging ? "battery.100.bolt" : "battery.100")
                if enableCaffeinate {
                    Label(caffeinate.isActive ? "Đang giữ máy thức" : "Giữ máy thức: Tắt",
                          systemImage: "cup.and.saucer")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 140, alignment: .leading)
        }
        .frame(height: 120)
        .environment(\.colorScheme, .dark)
    }
}

struct IdlePetPose {
    let x: CGFloat
    let facingRight: Bool
    let isWalking: Bool
    let step: Int

    static func sample(elapsed: TimeInterval, width: CGFloat, spriteWidth: CGFloat) -> IdlePetPose {
        let time = max(0, elapsed)
        let phase = time.truncatingRemainder(dividingBy: 14)
        let available = max(0, width - spriteWidth)
        let inset = min(12, available / 2)
        let distance = max(0, available - inset * 2)
        let progress: Double
        switch phase {
        case 0..<5: progress = phase / 5
        case 5..<7: progress = 1
        case 7..<12: progress = 1 - (phase - 7) / 5
        default: progress = 0
        }
        return IdlePetPose(
            x: inset + distance * progress,
            facingRight: phase < 7,
            isWalking: phase < 5 || (phase >= 7 && phase < 12),
            step: Int(time * 8) % 4
        )
    }
}

struct LocalIdlePetView: View {
    @EnvironmentObject private var vm: DynamicIslandViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var playedAt: Date?

    var body: some View {
        let frames = Self.pixelFrames
        Button {
            playedAt = Date()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 12.0,
                                    paused: reduceMotion || vm.notchState != .open)) { timeline in
                Canvas { context, size in
                    let unit = min(0.85, max(0, size.width / 96))
                    let spriteWidth = unit * 96
                    let elapsed = reduceMotion ? 6 : timeline.date.timeIntervalSince(startedAt)
                    let pose = IdlePetPose.sample(elapsed: elapsed, width: size.width, spriteWidth: spriteWidth)
                    let now = reduceMotion ? Date() : timeline.date
                    let reaction = playedAt.map { now.timeIntervalSince($0) } ?? 10
                    let isHappy = reaction >= 0 && reaction < 1.4
                    let jump = !reduceMotion && isHappy ? sin(min(1, reaction / 0.6) * .pi) * 10 : 0
                    let bob: CGFloat = pose.isWalking && pose.step % 2 == 1 ? 2 : 0
                    let y = size.height - unit * 100 - 4 - bob - jump

                    context.fill(Path(ellipseIn: CGRect(x: pose.x + unit * 14,
                                                        y: size.height - 5,
                                                        width: unit * 68, height: 3)),
                                 with: .color(.black.opacity(0.12)))
                    if isHappy {
                        context.draw(Text("♥").font(.system(size: 14)).foregroundColor(.pink),
                                     at: CGPoint(x: pose.x + spriteWidth / 2, y: max(8, y - 7)))
                    }

                    context.translateBy(x: pose.x + (pose.facingRight ? 0 : spriteWidth), y: y)
                    context.scaleBy(x: pose.facingRight ? unit : -unit, y: unit)
                    if let frame = frames[pose.isWalking ? pose.step : 4] {
                        context.draw(Image(decorative: frame, scale: 1).interpolation(.none),
                                     in: CGRect(x: 0, y: 0, width: 96, height: 100))
                    } else {
                        Self.drawCat(in: &context, walking: pose.isWalking, step: pose.step)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mèo pixel Anh lông dài màu xám tròn vo")
        .accessibilityHint("Bấm để chơi cùng mèo")
        .help("Bấm để chơi cùng mèo")
        .onAppear { startedAt = Date() }
        .task(id: playedAt) {
            guard playedAt != nil else { return }
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            playedAt = nil
        }
    }

    // Cache five tiny frames once; nearest-neighbor scaling keeps the pixels crisp.
    @MainActor private static let pixelFrames: [CGImage?] = (0..<5).map { frame in
        let renderer = ImageRenderer(content: Canvas { context, _ in
            drawCat(in: &context, walking: frame < 4, step: frame % 4)
        }.frame(width: 96, height: 100))
        renderer.scale = 0.5
        return renderer.cgImage
    }

    private static func drawCat(in context: inout GraphicsContext, walking: Bool, step: Int) {
        let outline = Color(red: 0.32, green: 0.36, blue: 0.44)
        let fur = Color(red: 0.65, green: 0.70, blue: 0.79)
        let lightFur = Color(red: 0.85, green: 0.88, blue: 0.93)

        // A short curled tail stays close to the round body.
        var tail = Path()
        tail.move(to: CGPoint(x: 13, y: 57))
        tail.addCurve(to: CGPoint(x: 21, y: 88), control1: CGPoint(x: -5, y: 64), control2: CGPoint(x: -1, y: 90))
        context.stroke(tail, with: .color(outline), style: StrokeStyle(lineWidth: 15, lineCap: .round))
        context.stroke(tail, with: .color(fur), style: StrokeStyle(lineWidth: 12, lineCap: .round))

        let body = Path(ellipseIn: CGRect(x: 5, y: 35, width: 86, height: 59))
        context.fill(body, with: .linearGradient(Gradient(colors: [lightFur, fur, outline.opacity(0.8)]),
                                               startPoint: CGPoint(x: 20, y: 36), endPoint: CGPoint(x: 84, y: 97)))
        context.stroke(body, with: .color(outline.opacity(0.6)), lineWidth: 0.8)
        context.fill(Path(ellipseIn: CGRect(x: 24, y: 57, width: 48, height: 35)), with: .color(lightFur.opacity(0.8)))

        for x in [26.0, 54.0] {
            let lift = walking && (step + (x == 26 ? 0 : 1)) % 2 == 0 ? 1.5 : 0
            let paw = Path(roundedRect: CGRect(x: x, y: 83 - lift, width: 17, height: 11), cornerRadius: 6)
            context.fill(paw, with: .color(lightFur))
            context.stroke(paw, with: .color(outline.opacity(0.45)), lineWidth: 0.8)
        }

        var ear = Path()
        ear.move(to: CGPoint(x: 14, y: 30))
        ear.addQuadCurve(to: CGPoint(x: 20, y: 9), control: CGPoint(x: 12, y: 6))
        ear.addQuadCurve(to: CGPoint(x: 37, y: 25), control: CGPoint(x: 27, y: 10))
        ear.closeSubpath()
        var innerEar = Path()
        innerEar.move(to: CGPoint(x: 19, y: 25))
        innerEar.addQuadCurve(to: CGPoint(x: 21, y: 15), control: CGPoint(x: 18, y: 12))
        innerEar.addQuadCurve(to: CGPoint(x: 30, y: 25), control: CGPoint(x: 26, y: 18))
        innerEar.closeSubpath()
        for mirrored in [false, true] {
            var side = context
            if mirrored {
                side.translateBy(x: 96, y: 0)
                side.scaleBy(x: -1, y: 1)
            }
            side.fill(ear, with: .color(fur))
            side.stroke(ear, with: .color(outline.opacity(0.65)), lineWidth: 1)
            side.fill(innerEar, with: .color(Color(red: 0.91, green: 0.68, blue: 0.75)))
        }

        let head = Path(ellipseIn: CGRect(x: 10, y: 17, width: 76, height: 59))
        let faceShade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(red: 0.82, green: 0.85, blue: 0.91), fur]),
            startPoint: CGPoint(x: 28, y: 20), endPoint: CGPoint(x: 66, y: 76))
        context.fill(head, with: faceShade)
        context.stroke(head, with: .color(outline.opacity(0.55)), lineWidth: 0.8)
        for x in [10.0, 62.0] {
            context.fill(Path(ellipseIn: CGRect(x: x, y: 46, width: 24, height: 25)), with: faceShade)
        }
        context.fill(Path(ellipseIn: CGRect(x: 30, y: 53, width: 36, height: 20)), with: .color(lightFur))

        for x in [26.0, 54.0] {
            context.fill(Path(ellipseIn: CGRect(x: x, y: 35, width: 16, height: 19)),
                         with: .color(Color(red: 0.99, green: 0.76, blue: 0.34)))
            context.fill(Path(ellipseIn: CGRect(x: x + 2.5, y: 36, width: 11, height: 16)),
                         with: .color(Color(red: 0.12, green: 0.15, blue: 0.21)))
            context.fill(Path(ellipseIn: CGRect(x: x + 3, y: 37, width: 5, height: 6)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: x + 10, y: 46, width: 2, height: 2)), with: .color(.white.opacity(0.9)))
        }
        for x in [19.0, 65.0] {
            context.fill(Path(ellipseIn: CGRect(x: x, y: 55, width: 12, height: 6)),
                         with: .color(Color.pink.opacity(0.2)))
        }

        var nose = Path()
        nose.move(to: CGPoint(x: 44, y: 57))
        nose.addQuadCurve(to: CGPoint(x: 52, y: 57), control: CGPoint(x: 48, y: 55))
        nose.addQuadCurve(to: CGPoint(x: 48, y: 62), control: CGPoint(x: 52, y: 60))
        nose.addQuadCurve(to: CGPoint(x: 44, y: 57), control: CGPoint(x: 44, y: 60))
        context.fill(nose, with: .color(Color(red: 0.89, green: 0.57, blue: 0.68)))
        var mouth = Path()
        mouth.move(to: CGPoint(x: 48, y: 62))
        mouth.addQuadCurve(to: CGPoint(x: 41, y: 64), control: CGPoint(x: 45, y: 69))
        mouth.move(to: CGPoint(x: 48, y: 62))
        mouth.addQuadCurve(to: CGPoint(x: 55, y: 64), control: CGPoint(x: 51, y: 69))
        context.stroke(mouth, with: .color(outline), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        var whiskers = Path()
        for (a, b) in [(CGPoint(x: 25, y: 59), CGPoint(x: 10, y: 56)),
                       (CGPoint(x: 24, y: 63), CGPoint(x: 8, y: 65)),
                       (CGPoint(x: 71, y: 59), CGPoint(x: 86, y: 56)),
                       (CGPoint(x: 72, y: 63), CGPoint(x: 88, y: 65))] {
            whiskers.move(to: a)
            whiskers.addLine(to: b)
        }
        context.stroke(whiskers, with: .color(outline.opacity(0.65)),
                       style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }
}
