require 'json'

module OS
  class Catalog
    attr_reader :language

    def initialize(directory:, policy:, environment: ENV)
      @policy = JSON.parse(File.read(policy))
      @directory = directory
      @language = resolve_language(environment)
      @messages = load_catalog(@language)
    end

    def text(key, *arguments)
      format(@messages.fetch(key), *arguments)
    end

    private

    def resolve_language(environment)
      candidate = @policy.fetch('environment').map { |name| environment[name] }.find { |value| value && !value.empty? && !%w[C POSIX].include?(value) }
      unless candidate
        file = @policy.fetch('systemFile')
        candidate = File.readlines(file).find { |line| line.start_with?('LANG=') }&.delete_prefix('LANG=')&.strip if File.readable?(file)
      end
      language = candidate.to_s.downcase.split(/[._@]/).first
      @policy.fetch('languages').include?(language) ? language : @policy.fetch('default')
    end

    def load_catalog(language)
      File.readlines(File.join(@directory, "#{language}.msg"), chomp: true).each_with_object({}) do |line, result|
        next if line.empty? || line.start_with?('#')
        key, value = line.split('=', 2)
        raise ArgumentError, key unless value && !result.key?(key)
        result[key] = value
      end
    end
  end
end
