require 'tmpdir'
require 'open3'
source = File.read(File.expand_path('../DynamicIsland/models/PlaybackState.swift', __dir__))
# Before the fix, the controller publishes every browser snapshot unchanged.
source += "\nextension PlaybackState { func removingExpiredBrowserSession(at: Date) -> PlaybackState { self } }\n" unless source.include?('func removingExpiredBrowserSession(')
checks = <<~SWIFT
  let now = Date(timeIntervalSince1970: 10000)
  var state = PlaybackState(bundleIdentifier: "com.apple.Safari", isPlaying: true, title: "Closed video", artist: "Channel", currentTime: 0.25, duration: 163, lastUpdated: now.addingTimeInterval(-600))
  let cleared = state.removingExpiredBrowserSession(at: now)
  assert(!cleared.isPlaying && cleared.title.isEmpty, "Expired browser video remains resumable")
  state.lastUpdated = now.addingTimeInterval(-10)
  assert(state.removingExpiredBrowserSession(at: now).title == state.title)
  state.lastUpdated = now.addingTimeInterval(-600)
  state.isPlaying = false
  assert(state.removingExpiredBrowserSession(at: now).title == state.title, "Paused sessions must survive")
  state.isPlaying = true
  state.duration = 0
  assert(state.removingExpiredBrowserSession(at: now).title == state.title, "Live streams must survive")
  state.duration = 163
  state.bundleIdentifier = "com.spotify.client"
  assert(state.removingExpiredBrowserSession(at: now).title == state.title, "Native players must survive")
  state.bundleIdentifier = "com.apple.Safari"
  state.isPlaying = false
  state.duration = 0
  state.playbackRate = 0
  let inactiveSince = now.addingTimeInterval(-10)
  assert(state.removingExpiredBrowserSession(at: now, inactiveSince: inactiveSince).title.isEmpty, "Stopped browser metadata must expire after ten seconds even without duration")
  assert(state.removingExpiredBrowserSession(at: now, inactiveSince: now.addingTimeInterval(-9)).title == state.title, "Allow a ten-second grace period")
  state.isPlaying = true
  state.playbackRate = 1
  assert(state.removingExpiredBrowserSession(at: now, inactiveSince: inactiveSince).title == state.title, "Resumed playback must survive")
  state.isPlaying = false
  state.bundleIdentifier = "com.spotify.client"
  assert(state.removingExpiredBrowserSession(at: now, inactiveSince: inactiveSince).title == state.title, "Native paused players must survive")
  print("PASS: expired/stopped browser sessions clear; ten-second grace, resumed/live playback and native players preserved")
SWIFT
Dir.mktmpdir('atoll-browser-test') do |dir|
  path = File.join(dir, 'main.swift')
  binary = File.join(dir, 'test')
  File.write(path, source + checks)
  output, status = Open3.capture2e('/usr/bin/xcrun', 'swiftc', path, '-o', binary)
  abort output unless status.success?
  output, status = Open3.capture2e(binary)
  puts output.lines.first(6)
  exit(status.success? ? 0 : 1)
end
