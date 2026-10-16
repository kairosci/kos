require 'fileutils'
require 'tmpdir'
require_relative '../scripts/boot-menu'

class BootMenuTest
  def assert_equal(expected, actual)
    raise "expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
  end

  def assert_includes(value, expected)
    raise "missing #{expected.inspect}" unless value.include?(expected)
  end

  def assert_raises(type)
    begin
      yield
    rescue type
      return
    end
    raise "expected #{type}"
  end

  def run
    failures = 0
    tests = public_methods.grep(/^test_/).sort
    tests.each do |test|
      setup
      begin
        public_send(test)
        puts "  pass #{test}"
      rescue StandardError => error
        failures += 1
        warn "  fail #{test}: #{error.message}"
      ensure
        teardown
      end
    end
    puts "Summary: Tests Executed: #{tests.length} | Passed: #{tests.length - failures} | Failed: #{failures} | Warnings: 0"
    failures.zero?
  end
  def setup
    @root = Dir.mktmpdir
    image = "MZ" + ("\x00" * 58) + [64].pack('V') + "PE\x00\x00" + ("\x00" * 64)
    File.binwrite(File.join(@root, 'kernel.efi'), image)
    @digest = OpenSSL::Digest.new('BLAKE2b512').file(File.join(@root, 'kernel.efi')).hexdigest
    @source = "/Arch\n //linux\n protocol: efi\n path: boot():/kernel.efi##{@digest}\n cmdline: cryptdevice=PARTUUID=fixture:root root=/dev/mapper/root rootflags=subvol=@ resume_offset=123 lsm=apparmor\n"
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_preserves_encryption_resume_and_security_arguments
    entries = BootMenu.verify_entries(BootMenu.read_entries(@source), @root)
    output = BootMenu.grub(entries, 'ABCD-1234')
    assert_includes output, "cryptdevice=PARTUUID=fixture:root"
    assert_includes output, "resume_offset=123"
    assert_includes output, "lsm=apparmor"
    assert_includes output, "rootflags=subvol=@"
  end

  def test_integrity_drift_is_rejected
    File.write(File.join(@root, 'kernel.efi'), 'MZchanged')
    assert_raises(ArgumentError) { BootMenu.verify_entries(BootMenu.read_entries(@source), @root) }
  end

  def test_parent_paths_are_rejected
    assert_raises(ArgumentError) { BootMenu.read_entries(@source.sub('/kernel.efi', '/../kernel.efi')) }
  end

  def test_missing_images_are_rejected
    File.unlink(File.join(@root, 'kernel.efi'))
    assert_raises(Errno::ENOENT) { BootMenu.verify_entries(BootMenu.read_entries(@source), @root) }
  end

  def test_kernel_argument_quotes_are_preserved_verbatim
    entries = BootMenu.read_entries(@source.sub('lsm=apparmor', 'example="two words" lsm=apparmor'))
    assert_includes BootMenu.grub(entries, 'ABCD-1234'), 'example="two words"'
  end

  def test_non_pe_files_are_rejected
    File.binwrite(File.join(@root, 'kernel.efi'), "MZ" + ("\x00" * 126))
    assert_raises(ArgumentError) { BootMenu.verify_entries(BootMenu.read_entries(@source), @root) }
  end

  def test_duplicate_fields_are_rejected
    assert_raises(ArgumentError) { BootMenu.read_entries(@source + " path: boot():/kernel.efi\n") }
  end

  def test_snapshot_arguments_remain_distinct
    source = @source + " ///Snapshots\n ////saved\n protocol: efi\n path: boot():/kernel.efi##{@digest}\n cmdline: rootflags=subvol=/@/.snapshots/24/snapshot\n"
    entries = BootMenu.read_entries(source)
    assert_equal 2, entries.length
    assert_equal 'rootflags=subvol=/@/.snapshots/24/snapshot', entries.last['cmdline']
  end

  def test_grub_strings_cannot_inject_commands
    entry = { 'title' => "test'; reboot; '", 'path' => '/kernel.efi', 'cmdline' => 'root=/dev/mapper/root' }
    assert_includes BootMenu.grub([entry], 'ABCD-1234'), %q('test'\''; reboot; '\''')
    assert_raises(ArgumentError) { BootMenu.quote("test\nreboot") }
  end
end

exit(BootMenuTest.new.run ? 0 : 1)
