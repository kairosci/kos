require 'tmpdir'

class PublicationTest
  def run
    root = File.expand_path('../../..', __dir__)
    library = File.join(root, 'scripts/lib/userconf.sh')
    Dir.mktmpdir do |directory|
      target = File.join(directory, 'hyprland.lua')
      first = 'a' * 131_072
      second = 'b' * 131_072
      File.binwrite(target, first)
      File.binwrite(File.join(directory, 'first'), first)
      File.binwrite(File.join(directory, 'second'), second)
      script = <<~BASH
        set -euo pipefail
        source "$1"
        for ((iteration=0; iteration<100; iteration++)); do
          install_user_file "$2/second" "$2/hyprland.lua" 600
          install_user_file "$2/first" "$2/hyprland.lua" 600
        done
      BASH
      child = Process.spawn('bash', '-c', script, 'publication-test', library, directory)
      observations = 0
      failure = nil
      loop do
        begin
          content = File.binread(target)
          failure = 'partially published configuration' unless content == first || content == second
        rescue Errno::ENOENT
          failure = 'watched configuration disappeared'
        end
        observations += 1
        break if Process.waitpid(child, Process::WNOHANG)
        Thread.pass
      end
      check($?.success?)
      check(failure.nil?)
      check(observations.positive?)
      check(File.binread(target) == first)
      check(File.binread(target + '.bak') == second)
      check((File.stat(target).mode & 0o777) == 0o600)
      check((File.stat(target + '.bak').mode & 0o777) == 0o600)
      unchanged = File.stat(target).ino
      check(system('bash', '-c', 'set -euo pipefail; source "$1"; install_user_file "$2/first" "$2/hyprland.lua" 600', 'publication-test', library, directory))
      check(File.stat(target).ino == unchanged)
      check(!system('bash', '-c', 'set -euo pipefail; source "$1"; install_user_file "$2/missing" "$2/hyprland.lua"', 'publication-test', library, directory))
      check(File.binread(target) == first)
    end
    puts "Summary: Tests Executed: #{@count} | Passed: #{@count} | Failed: 0 | Warnings: 0"
  end

  def check(value)
    raise 'configuration publication assertion failed' unless value
    @count = (@count || 0) + 1
    puts "  pass publication invariant #{@count}"
  end
end

PublicationTest.new.run
