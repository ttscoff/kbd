#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'kbd_automator_core'

config = KbdAutomator::Config.load
input = KbdAutomator::CLI.read_input(ARGV, $stdin)

unless input
  KbdAutomator::CLI.print_help(File.basename(__FILE__), $stderr)
  exit 1
end

kbd = config.fetch('kbd', {})
formatter = KbdAutomator::Formatter.new(
  use_modifier_symbols: kbd.fetch('use_modifier_symbols', true),
  use_key_symbols: kbd.fetch('use_key_symbols', true),
  use_plus_sign: kbd.fetch('use_plus_sign', false)
)

puts formatter.render_html(input)
