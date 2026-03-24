#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tmpdir'

begin
  require 'plist'
rescue LoadError
  abort 'Missing gem `plist`. Install with: gem install plist'
end

CORE_FILE = 'kbd_automator_core.rb'
DIST_DIR = 'dist'
VERSION_FILE = 'VERSION'
WORKFLOW_SOURCE_DIR = 'automator'
WORKFLOW_BUILD_DIR = File.join(WORKFLOW_SOURCE_DIR, 'Automator Actions')
AUTOMATOR_ZIP = 'KBD Automator Actions.zip'
SIGNING_ID = ENV.fetch('SIGNING_ID', 'Apple Development: Brett Terpstra')
WORKFLOWS = {
  'KBD HTML.workflow.template' => File.join(DIST_DIR, 'kbd.rb'),
  'KBD Text.workflow.template' => File.join(DIST_DIR, 'kbd-text.rb')
}.freeze

def current_version
  abort "Missing #{VERSION_FILE}" unless File.exist?(VERSION_FILE)

  File.read(VERSION_FILE).strip
end

def add_version_comment(source, version)
  lines = source.lines
  lines.reject! { |line| line.start_with?('# version: ') }

  insert_at = 0
  insert_at += 1 if lines[0]&.start_with?('#!')
  insert_at += 1 if lines[insert_at]&.start_with?('# frozen_string_literal:')
  lines.insert(insert_at, "# version: #{version}\n")
  lines.join
end

def update_workflow_script!(workflow_path, script_path)
  wflow = File.join(workflow_path, 'Contents', 'document.wflow')
  abort "Missing workflow file #{wflow}" unless File.exist?(wflow)
  abort "Missing built script #{script_path}" unless File.exist?(script_path)

  plist = Plist.parse_xml(wflow)
  script = File.read(script_path)

  updated = false
  plist['actions'].each_with_index do |action, idx|
    params = action.dig('action', 'ActionParameters')
    next unless params&.key?('COMMAND_STRING')

    plist['actions'][idx]['action']['ActionParameters']['COMMAND_STRING'] = script
    updated = true
    break
  end

  abort "Could not find COMMAND_STRING in #{wflow}" unless updated

  File.write(wflow, plist.to_plist)
end

def sign_workflow!(workflow_path)
  escaped = Shellwords.escape(workflow_path)
  system("xattr -cr #{escaped}")

  cmd = [
    'codesign',
    '--force',
    '--deep',
    '--verbose',
    "--sign #{Shellwords.escape(SIGNING_ID)}",
    '-o runtime',
    '--timestamp',
    escaped
  ].join(' ')

  ok = system(cmd)
  abort "codesign failed for #{workflow_path}" unless ok
end

desc 'Build self-contained Automator scripts into dist/'
task :build do
  abort "Missing #{CORE_FILE}" unless File.exist?(CORE_FILE)
  version = current_version

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
    inlined = add_version_comment(inlined, version)

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

  if Dir.exist?(WORKFLOW_BUILD_DIR)
    FileUtils.rm_rf(WORKFLOW_BUILD_DIR)
    puts "Removed #{WORKFLOW_BUILD_DIR}/"
  end

  if File.exist?(AUTOMATOR_ZIP)
    FileUtils.rm_f(AUTOMATOR_ZIP)
    puts "Removed #{AUTOMATOR_ZIP}"
  end
end

namespace :build do
  desc 'Build and sign Automator workflows, then create Automator Actions.zip'
  task automator: :build do
    WORKFLOWS.each_value do |script_path|
      abort "Missing #{script_path}. Run rake build first." unless File.exist?(script_path)
    end
    abort "Missing #{WORKFLOW_SOURCE_DIR}/" unless Dir.exist?(WORKFLOW_SOURCE_DIR)

    FileUtils.rm_rf(WORKFLOW_BUILD_DIR)
    FileUtils.rm_f(AUTOMATOR_ZIP)
    FileUtils.mkdir_p(WORKFLOW_BUILD_DIR)

    WORKFLOWS.each do |template_name, script_path|
      source_workflow = File.join(WORKFLOW_SOURCE_DIR, template_name)
      target_name = template_name.sub(/\.template\z/, '')
      target_workflow = File.join(WORKFLOW_BUILD_DIR, target_name)

      abort "Missing #{source_workflow}" unless Dir.exist?(source_workflow)

      FileUtils.cp_r(source_workflow, target_workflow)
      update_workflow_script!(target_workflow, script_path)
      sign_workflow!(target_workflow)
      puts "Prepared and signed #{target_workflow}"
    end

    workflow_names = WORKFLOWS.keys.map { |name| name.sub(/\.template\z/, '') }
    zip_items = workflow_names.map { |name| Shellwords.escape(name) }.join(' ')
    cmd = "cd #{Shellwords.escape(WORKFLOW_BUILD_DIR)} && zip -qry #{Shellwords.escape(File.join('..', '..', AUTOMATOR_ZIP))} #{zip_items}"
    ok = system(cmd)
    abort "Failed to create #{AUTOMATOR_ZIP}" unless ok

    puts "Created #{AUTOMATOR_ZIP}"
  end
end

desc 'Bump version in VERSION (maj|min|patch, default: patch)'
task :bump, [:type] do |_, args|
  args.with_defaults(type: 'patch')
  version = current_version
  match = version.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
  abort "Invalid VERSION format: #{version}" unless match

  major = match[1].to_i
  minor = match[2].to_i
  patch = match[3].to_i

  case args[:type]
  when /^maj/
    major += 1
    minor = 0
    patch = 0
  when /^min/
    minor += 1
    patch = 0
  else
    patch += 1
  end

  new_version = "#{major}.#{minor}.#{patch}"
  File.write(VERSION_FILE, "#{new_version}\n")
  puts "Bumped version: #{version} -> #{new_version}"
end

desc 'Bump version, build automator zip, commit/tag, and create GitHub release'
task :deploy, [:type] do |_, args|
  args.with_defaults(type: 'patch')
  Rake::Task[:bump].invoke(args[:type])
  Rake::Task['build:automator'].invoke

  version = current_version
  tag = version
  tag_ref = "refs/tags/#{tag}"

  ok = system("git add #{Shellwords.escape(VERSION_FILE)} #{Shellwords.escape(DIST_DIR)}")
  abort 'git add failed' unless ok

  message = "Release #{version}"
  ok = system("git commit -m #{Shellwords.escape(message)}")
  abort 'git commit failed' unless ok

  tag_exists = system("git rev-parse -q --verify #{Shellwords.escape(tag_ref)} > /dev/null 2>&1")
  unless tag_exists
    ok = system("git tag -a #{Shellwords.escape(tag)} -m #{Shellwords.escape("v#{tag}")}")
    abort 'git tag failed' unless ok
  end

  ok = system("git push origin #{Shellwords.escape(tag_ref)}")
  abort 'git push tag failed' unless ok

  notes_file = 'release_notes.txt'
  ok = system("changelog > #{Shellwords.escape(notes_file)}")
  abort 'changelog failed' unless ok

  ok = system("gh release create #{Shellwords.escape(tag)} #{Shellwords.escape(AUTOMATOR_ZIP)} --title #{Shellwords.escape(tag)} --notes-file #{Shellwords.escape(notes_file)}")
  abort 'gh release create failed' unless ok

  FileUtils.rm_f(notes_file)
  FileUtils.rm_f(AUTOMATOR_ZIP)
  puts "Removed local #{AUTOMATOR_ZIP}"

  puts "Released #{tag} with #{AUTOMATOR_ZIP}"
end
