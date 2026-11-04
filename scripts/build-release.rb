require 'fileutils'
require 'open3'
require 'tmpdir'
require 'find'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
abort 'Commit source changes before packaging so the source ZIP matches the app.' unless `git status --porcelain`.empty?

def run(*args, **options)
  abort "Failed: #{args.first}" unless system(*args, **options)
end

derived = ENV.fetch('ATOLL_RELEASE_DERIVED_DATA', '/tmp/AtollReleaseDerivedData')
source_app = ENV['ATOLL_BUILT_APP']
unless source_app
  log = File.join(Dir.tmpdir, 'atoll-release-build.log')
  puts "Building Apple Silicon Release. Log: #{log}"
  File.open(log, 'w') do |output|
    run({'DEVELOPER_DIR' => ENV.fetch('DEVELOPER_DIR', '/Applications/Xcode.app/Contents/Developer')},
        'xcodebuild', '-project', 'DynamicIsland.xcodeproj', '-scheme', 'DynamicIsland',
        '-configuration', 'Release', '-destination', 'generic/platform=macOS',
        '-derivedDataPath', derived, '-clonedSourcePackagesDirPath', '.build/SourcePackages',
        '-jobs', '4', 'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=YES', 'CODE_SIGNING_ALLOWED=NO',
        'PRODUCT_BUNDLE_IDENTIFIER=local.atoll.validation', 'build', out: output, err: output)
  end
  source_app = File.join(derived, 'Build/Products/Release/Atoll.app')
end
abort 'Built app not found' unless File.directory?(source_app)
architectures, status = Open3.capture2e('lipo', '-archs', File.join(source_app, 'Contents/MacOS/Atoll'))
abort 'Expected an Apple Silicon (arm64) app' unless status.success? && architectures.split == ['arm64']

output = File.join(root, 'build')
FileUtils.mkdir_p(output)
app = File.join(output, 'Atoll Local.app')
if File.exist?(app)
  backup = Dir.mktmpdir('atoll-before-package-')
  FileUtils.mv(app, backup)
end
run('ruby', 'scripts/package-offline.rb', source_app)

source_zip = File.join(output, 'Atoll-Local-Source.zip')
dmg = File.join(output, 'Atoll-Local-AppleSilicon.dmg')
revision, revision_status = Open3.capture2('git', 'rev-parse', 'HEAD')
abort 'Cannot identify source revision' unless revision_status.success?

Dir.mktmpdir('atoll-share-') do |stage|
  source_root = File.join(stage, 'source', 'Atoll-Local')
  FileUtils.mkdir_p(source_root)
  tracked, tracked_status = Open3.capture2('git', 'ls-files', '-z')
  abort 'Cannot list source' unless tracked_status.success?
  tracked.split("\0").each do |relative|
    destination = File.join(source_root, relative)
    FileUtils.mkdir_p(File.dirname(destination))
    if File.symlink?(relative)
      File.symlink(File.readlink(relative), destination)
    else
      FileUtils.cp(relative, destination)
    end
  end

  # Include the exact checked-out dependency sources, without their Git metadata or caches.
  dependencies = File.join(source_root, 'DependencySources')
  Dir.glob('.build/SourcePackages/checkouts/*').select { |path| File.directory?(path) }.each do |checkout|
    destination_root = File.join(dependencies, File.basename(checkout))
    Find.find(checkout) do |path|
      if %w[.git .build .swiftpm].include?(File.basename(path))
        File.directory?(path) ? Find.prune : next
      end
      relative = path.delete_prefix(checkout).sub(%r{\A/}, '')
      destination = File.join(destination_root, relative)
      if File.symlink?(path)
        FileUtils.mkdir_p(File.dirname(destination))
        File.symlink(File.readlink(path), destination)
      elsif File.directory?(path)
        FileUtils.mkdir_p(destination)
      elsif File.basename(path) != '.DS_Store'
        FileUtils.cp(path, destination)
      end
    end
  end
  File.write(File.join(source_root, 'SOURCE_REVISION'), revision.strip + "\n")
  FileUtils.rm_f(source_zip)
  run('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', source_root, source_zip)

  volume = File.join(stage, 'volume')
  FileUtils.mkdir_p(volume)
  run('/usr/bin/ditto', app, File.join(volume, 'Atoll Local.app'))
  File.symlink('/Applications', File.join(volume, 'Applications'))
  FileUtils.cp(source_zip, volume)
  %w[LICENSE NOTICE COPYRIGHT_ASSETS TRADEMARKS].each { |name| FileUtils.cp(name, volume) }
  FileUtils.cp('docs/INSTALL.vi.txt', File.join(volume, 'Cai-dat.txt'))
  run('/usr/bin/hdiutil', 'create', '-volname', 'Atoll Local', '-srcfolder', volume,
      '-ov', '-format', 'UDZO', dmg)
end
run('/usr/bin/codesign', '--verify', '--deep', '--strict', app)
run('/usr/bin/hdiutil', 'verify', dmg)
puts "Installer: #{dmg}"
puts "Source: #{source_zip}"
