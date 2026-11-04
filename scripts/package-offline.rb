require 'fileutils'
require 'open3'

root = File.expand_path('..', __dir__)
source = ARGV.fetch(0) { abort 'Usage: ruby scripts/package-offline.rb PATH_TO_BUILT_APP' }
abort 'Built app is missing' unless File.executable?(File.join(source, 'Contents/MacOS/Atoll'))
identities, identity_status = Open3.capture2e('/usr/bin/security', 'find-identity', '-v', '-p', 'codesigning')
signing_identity = ENV['ATOLL_SIGNING_IDENTITY'] || (identity_status.success? && identities[/\b([A-Fa-f0-9]{40}) "Apple Development:/, 1]) || '-'
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
licenses = File.join(resources, 'Licenses')
FileUtils.mkdir_p(licenses)
%w[LICENSE NOTICE COPYRIGHT_ASSETS TRADEMARKS].each do |name|
  FileUtils.cp(File.join(root, name), licenses)
end
Dir.glob(File.join(root, '.build/SourcePackages/checkouts/*')).each do |dependency|
  Dir.glob(File.join(dependency, '{LICENSE*,COPYING*,NOTICE*}')).select { |path| File.file?(path) }.each do |path|
    destination_name = "#{File.basename(dependency)}-#{File.basename(path)}"
    FileUtils.cp(path, File.join(licenses, destination_name))
  end
end
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
