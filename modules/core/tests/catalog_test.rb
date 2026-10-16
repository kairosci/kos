require 'tmpdir'
require_relative '../scripts/catalog'

class CatalogTest
  def run
    root = File.expand_path('../../..', __dir__)
    directory = File.join(root, 'scripts/lib/messages')
    Dir.mktmpdir do |temporary|
      policy = JSON.parse(File.read(File.join(__dir__, '../data/locale.json')))
      policy['systemFile'] = File.join(temporary, 'locale.conf')
      path = File.join(temporary, 'policy.json')
      File.write(path, JSON.generate(policy))
      File.write(policy['systemFile'], "LANG=fr_FR.UTF-8\n")
      policy.fetch('languages').each do |language|
        catalog = OS::Catalog.new(directory: directory, policy: path, environment: { 'OS_LANG' => "#{language}_XX.UTF-8", 'LANG' => 'de_DE.UTF-8' })
        check(catalog.language == language)
        check(catalog.text('boot.validation_failed', 'invalid_efi').include?('invalid_efi'))
      end
      check(OS::Catalog.new(directory: directory, policy: path, environment: {}).language == 'fr')
      check(OS::Catalog.new(directory: directory, policy: path, environment: { 'LANG' => 'C' }).language == 'fr')
      check(OS::Catalog.new(directory: directory, policy: path, environment: { 'OS_LANG' => 'xx' }).language == 'en')
      begin
        OS::Catalog.new(directory: directory, policy: path, environment: {}).text('missing.key')
        raise 'missing translation accepted'
      rescue KeyError
        check(true)
      end
    end
    puts "Summary: Tests Executed: #{@count} | Passed: #{@count} | Failed: 0 | Warnings: 0"
  end

  def check(value)
    raise 'catalog assertion failed' unless value
    @count = (@count || 0) + 1
    puts "  pass catalog invariant #{@count}"
  end
end

CatalogTest.new.run
