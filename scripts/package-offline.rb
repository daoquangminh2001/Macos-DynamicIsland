require 'fileutils'
require 'open3'

root = File.expand_path('..', __dir__)
source = ARGV.fetch(0) { abort 'Usage: ruby scripts/package-offline.rb PATH_TO_BUILT_APP' }
abort 'Built app is missing' unless File.executable?(File.join(source, 'Contents/MacOS/Atoll'))
identities, identity_status = Open3.capture2e('/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning')
signing_identity = ENV['ATOLL_SIGNING_IDENTITY'] || (identity_status.success? && identities[/\b([A-Fa-f0-9]{40}) "Apple Development:/, 1])
abort 'A stable signing identity is required; set ATOLL_SIGNING_IDENTITY to a valid certificate.' unless signing_identity
destination = File.join(root, 'build', 'Atoll Local.app')
abort 'Output already exists; move it aside before repackaging' if File.exist?(destination)
FileUtils.mkdir_p(File.dirname(destination))
def run(*args)
  abort "Failed: #{args.first}" unless system(*args)
end
run('/usr/bin/ditto', source, destination)
Dir.glob(File.join(destination, 'Contents/PlugIns/*.xctest')).each { |path| FileUtils.rm_r(path) }
resources = File.join(destination, 'Contents/Resources')
FileUtils.cp(File.join(__dir__, 'offline.sb'), resources)
plist = File.join(destination, 'Contents/Info.plist')
{
  'CFBundleIdentifier' => 'local.atoll.private',
  'CFBundleName' => 'Atoll Local',
  'CFBundleDisplayName' => 'Atoll Local'
}.each { |key, value| run('/usr/bin/plutil', '-replace', key, '-string', value, plist) }
run('/usr/bin/plutil', '-replace', 'AtollLocalOfflineBuild', '-bool', 'YES', plist)
run('/usr/bin/codesign', '--force', '--deep', '--timestamp=none', '--sign', signing_identity, destination)
run('/usr/bin/codesign', '--verify', '--deep', '--strict', destination)
puts destination
