require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/components/LocalIdlePetView.swift'))
renderer = source[/    \/\/ Cache five tiny frames.*\z/m]&.sub(/\n}\s*\z/, "\n")
abort 'Pixel renderer not found' unless renderer
checks = <<~'SWIFT'
      static func verify() {
          assert(pixelFrames.count == 5)
          for frame in pixelFrames {
              guard let frame else { fatalError("Pet renderer returned a missing frame") }
              assert(frame.width == 48 && frame.height == 50, "Pet must render at pixel resolution")
              guard let data = frame.dataProvider?.data,
                    let bytes = CFDataGetBytePtr(data) else { fatalError("Pet frame has no pixels") }
              let pixels = UnsafeBufferPointer(start: bytes, count: CFDataGetLength(data))
              assert(pixels.contains { $0 != 0 }, "Pet frame must not be blank")
          }
          print("PASS: five non-empty 48x50 pet animation frames")
      }
  }
  @main struct Tests {
      @MainActor static func main() {
          _ = NSApplication.shared
          PetRenderer.verify()
      }
  }
SWIFT
Dir.mktmpdir('atoll-pet-render') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'render-tests')
  File.write(swift, "import SwiftUI\nimport AppKit\n@MainActor enum PetRenderer {\n" + renderer + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', '-parse-as-library', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.grep(/PASS|failed|error/i).first(6)
  exit(status.success? ? 0 : 1)
end
