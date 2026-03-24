#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

CORE_FILE = 'kbd_automator_core.rb'
DIST_DIR = 'dist'

desc 'Build self-contained Automator scripts into dist/'
task :build do
  abort "Missing #{CORE_FILE}" unless File.exist?(CORE_FILE)

  FileUtils.mkdir_p(DIST_DIR)

  core = File.read(CORE_FILE)
             .sub(/\A#![^\n]*\n/, '')
             .sub(/\A# frozen_string_literal: true\n/, '')
             .rstrip

  scripts = Dir.glob('*.rb').reject { |f| [CORE_FILE, 'Rakefile'].include?(f) }
  if scripts.empty?
    puts 'No scripts found to build.'
    next
  end

  scripts.each do |script|
    source = File.read(script)
    inlined = source.sub(/^\s*require_relative\s+['"]kbd_automator_core['"]\s*\n?/) do
      "#{core}\n\n"
    end

    output = File.join(DIST_DIR, script)
    File.write(output, inlined)
    FileUtils.chmod(File.stat(script).mode, output)
    puts "Built #{output}"
  end
end

desc 'Remove generated dist/ output'
task :clean do
  if Dir.exist?(DIST_DIR)
    FileUtils.rm_rf(DIST_DIR)
    puts "Removed #{DIST_DIR}/"
  else
    puts "#{DIST_DIR}/ does not exist."
  end
end
