require 'tmpdir'
require 'open3'

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'DynamicIsland/components/LocalIdlePetView.swift'))
motion = source[/struct IdlePetPose.*?(?=struct LocalIdlePetView)/m]
abort 'Pet motion was not found' unless motion
checks = <<~'SWIFT'
  for width in [0.0, 40, 81.6, 84, 91, 120, 330, 640, 1024] {
      let spriteWidth = min(81.6, width)
      for tick in 0...1400 {
          let pose = IdlePetPose.sample(elapsed: Double(tick) / 50, width: width, spriteWidth: spriteWidth)
          assert(pose.x.isFinite && pose.x >= 0 && pose.x + spriteWidth <= width + 0.001,
                 "Pet must stay inside its lane, including narrow windows")
      }
      let a = IdlePetPose.sample(elapsed: 6.999, width: width, spriteWidth: spriteWidth)
      let b = IdlePetPose.sample(elapsed: 7, width: width, spriteWidth: spriteWidth)
      assert(abs(a.x - b.x) < 0.001, "Turning around must not teleport the pet")
  }
  assert(!IdlePetPose.sample(elapsed: 6, width: 640, spriteWidth: 84).isWalking)
  assert(!IdlePetPose.sample(elapsed: 13, width: 640, spriteWidth: 84).isWalking)
  assert(IdlePetPose.sample(elapsed: 1, width: 640, spriteWidth: 84).facingRight)
  assert(!IdlePetPose.sample(elapsed: 8, width: 640, spriteWidth: 84).facingRight)
  let start = IdlePetPose.sample(elapsed: 0, width: 640, spriteWidth: 84)
  let loop = IdlePetPose.sample(elapsed: 14, width: 640, spriteWidth: 84)
  assert(start.x == loop.x && start.facingRight == loop.facingRight)
  print("PASS: pet remains in bounds, rests, reverses continuously and loops")
SWIFT
Dir.mktmpdir('atoll-idle-pet') do |dir|
  swift = File.join(dir, 'main.swift')
  binary = File.join(dir, 'pet-tests')
  File.write(swift, "import Foundation\n" + motion + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', swift, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.first(5)
  exit(status.success? ? 0 : 1)
end
