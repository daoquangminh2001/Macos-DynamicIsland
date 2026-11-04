require 'tmpdir'
require 'fileutils'
require 'open3'
require 'socket'

profile = File.expand_path('../scripts/offline.sb', __dir__)
Dir.mktmpdir('atoll-offline-test', '/private/tmp') do |home|
  home = File.realpath(home)
  FileUtils.mkdir_p(File.join(home, '.codex'))
  secret = File.join(home, '.codex/auth.json')
  ordinary = File.join(home, 'ordinary.txt')
  File.write(secret, 'FAKE TEST CREDENTIAL')
  File.write(ordinary, 'ordinary file')
  sandbox = ['/usr/bin/sandbox-exec', '-D', "USER_HOME=#{home}", '-f', profile]
  output, status = Open3.capture2e(*sandbox, '/bin/cat', secret)
  abort 'Credential fixture was readable' if status.success? || output.include?('FAKE TEST CREDENTIAL')
  _, status = Open3.capture2e(*sandbox, '/bin/sh', '-c', 'echo changed > "$1"', 'test', secret)
  abort 'Credential fixture was writable' if status.success? || File.read(secret) != 'FAKE TEST CREDENTIAL'
  output, status = Open3.capture2e(*sandbox, '/bin/cat', ordinary)
  abort 'Ordinary files should remain readable' unless status.success? && output == 'ordinary file'
  server = TCPServer.new('127.0.0.1', 0)
  port = server.addr[1]
  probe = 'require "socket"; TCPSocket.new("127.0.0.1", ARGV.fetch(0).to_i).close'
  _, status = Open3.capture2e('/usr/bin/ruby', '-e', probe, port.to_s)
  abort 'Baseline network probe failed' unless status.success?
  output, status = Open3.capture2e(*sandbox, '/usr/bin/ruby', '-e', probe, port.to_s)
  abort 'Sandbox allowed network or failed for an unrelated reason' if status.success? || !output.include?('Operation not permitted')
  output, status = Open3.capture2e(*sandbox, '/bin/sh', '-c', 'exec /usr/bin/ruby -e "$1" "$2"', 'test', probe, port.to_s)
  abort 'Child process escaped network restriction' if status.success? || !output.include?('Operation not permitted')
  [
    'require "socket"; UDPSocket.new.send("test", 0, "127.0.0.1", 9)',
    'require "socket"; TCPServer.new("127.0.0.1", 0)'
  ].each do |ip_probe|
    output, status = Open3.capture2e(*sandbox, '/usr/bin/ruby', '-e', ip_probe)
    abort 'IP UDP/listener was not blocked' if status.success? || !output.include?('Operation not permitted')
  end
  unix_probe = 'require "socket"; server = UNIXServer.new(ARGV.fetch(0)); client = UNIXSocket.new(ARGV.fetch(0)); client.close; server.close'
  output, status = Open3.capture2e(*sandbox, '/usr/bin/ruby', '-e', unix_probe, File.join(home, 'ui-ipc.sock'))
  abort "Local UI IPC must remain available: #{output}" unless status.success?
  server.close
  puts 'PASS: IP TCP/UDP/listeners and child IP blocked; local Unix IPC allowed; credential reads/writes blocked'
end
