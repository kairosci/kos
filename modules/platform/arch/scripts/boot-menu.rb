require 'json'
require 'openssl'
require 'pathname'
require_relative '../../../core/scripts/catalog'

module BootMenu
  module_function

  def read_entries(text)
    hierarchy = []
    entries = []
    current = nil
    text.each_line do |line|
      if (heading = line.match(%r{^\s*(/+)([^/].*)$}))
        depth = heading[1].length
        hierarchy = hierarchy.take(depth - 1)
        hierarchy << heading[2].strip
        current = { 'title' => hierarchy.join(' / ') }
        entries << current
      elsif current && (field = line.match(/^\s*(protocol|path|cmdline):\s*(.*?)\s*$/))
        raise ArgumentError, "duplicate #{field[1]}" if current.key?(field[1])
        current[field[1]] = field[2]
      end
    end
    entries.select { |entry| entry.key?('path') }.map do |entry|
      raise ArgumentError, 'unsupported protocol' unless entry['protocol'] == 'efi'
      match = entry.fetch('path').match(%r{\Aboot\(\):(/[^#\s]+)(?:#([a-fA-F0-9]{128}))?\z})
      raise ArgumentError, 'unsupported EFI path' unless match
      path = match[1]
      raise ArgumentError, 'unsafe EFI path' if path.split('/').include?('..')
      entry.merge('path' => path, 'blake2b' => match[2], 'cmdline' => entry.fetch('cmdline', ''))
    end
  end

  def verify_entries(entries, esp)
    raise ArgumentError, 'no EFI entries' if entries.empty?
    root = Pathname.new(esp).realpath
    entries.each do |entry|
      path = root.join(entry.fetch('path').delete_prefix('/')).realpath
      raise ArgumentError, 'EFI path escapes ESP' unless path.to_s.start_with?(root.to_s + '/')
      raise ArgumentError, 'empty EFI image' unless path.file? && path.size.positive?
      header = File.binread(path, 64)
      raise ArgumentError, 'invalid EFI image header' unless header.bytesize == 64 && header.start_with?('MZ')
      offset = header.byteslice(60, 4).unpack1('V')
      raise ArgumentError, 'invalid PE offset' unless offset.between?(64, path.size - 24)
      signature = File.binread(path, 4, offset)
      raise ArgumentError, 'invalid PE signature' unless signature == "PE\x00\x00"
      digest = entry['blake2b']
      raise ArgumentError, 'EFI integrity mismatch' if digest && OpenSSL::Digest.new('BLAKE2b512').file(path).hexdigest != digest.downcase
    end
    entries
  end

  def quote(value)
    raise ArgumentError, 'unsafe GRUB string' if value.match?(/[\r\n\x00]/)
    "'#{value.gsub("'") { %q('\'') }}'"
  end

  def grub(entries, uuid, policy = JSON.parse(File.read(File.join(__dir__, '../data/boot.json'))).fetch('menu'))
    raise ArgumentError, 'invalid ESP UUID' unless uuid.match?(/\A[[:alnum:]-]+\z/)
    timeout = Integer(policy.fetch('timeout'))
    default = Integer(policy.fetch('default'))
    raise ArgumentError, 'invalid menu policy' unless timeout.between?(1, 60) && default.between?(0, entries.length - 1) && policy['terminal'] == 'console'
    lines = ["set timeout=#{timeout}", "set default=#{default}", 'terminal_output console', 'insmod part_gpt', 'insmod fat', 'insmod chain']
    %w[colorNormal colorHighlight].each do |key|
      raise ArgumentError, 'invalid menu color' unless policy.fetch(key).match?(%r{\A[a-z]+/[a-z]+\z})
    end
    lines << "set menu_color_normal=#{quote(policy.fetch('colorNormal'))}"
    lines << "set menu_color_highlight=#{quote(policy.fetch('colorHighlight'))}"
    entries.each do |entry|
      entry = entry.merge('title' => entry.fetch('title').sub(%r{\A[^/]+ / }, policy.fetch('rootTitle') + ' / '))
      lines << "menuentry #{quote(entry.fetch('title'))} {"
      lines << "  search --no-floppy --fs-uuid --set=root #{quote(uuid)}"
      lines << "  chainloader #{quote(entry.fetch('path'))} #{quote(entry.fetch('cmdline'))}"
      lines << '}'
    end
    lines.join("\n") + "\n"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    mode, config, esp, uuid, policy_path = ARGV
    raise ArgumentError, 'invalid arguments' unless %w[report grub].include?(mode) && config && esp && (mode != 'grub' || uuid)
    entries = BootMenu.verify_entries(BootMenu.read_entries(File.read(config)), esp)
    puts(mode == 'report' ? JSON.pretty_generate({ 'entries' => entries, 'trialBootVerified' => false }) : BootMenu.grub(entries, uuid, JSON.parse(File.read(policy_path || File.join(__dir__, '../data/boot.json'))).fetch('menu')))
  rescue ArgumentError, KeyError, SystemCallError => error
    root = File.expand_path('../../../..', __dir__)
    catalog = OS::Catalog.new(directory: ENV.fetch('OS_I18N_DIR', File.join(root, 'scripts/lib/messages')),
                              policy: File.join(root, 'modules/core/data/locale.json'))
    code = error.is_a?(SystemCallError) ? error.class.name : error.message.downcase.gsub(/[^a-z0-9]+/, '_')
    warn catalog.text('boot.validation_failed', code)
    exit 1
  end
end
