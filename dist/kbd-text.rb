#!/usr/bin/env ruby
# frozen_string_literal: true
# version: 1.0.3

require 'fileutils'
require 'yaml'

class String
  def clean_combo
    gsub!(/(?<=\S)-(?=\S)/, ' ')
    gsub!(/\b(comm(and)?|cmd|clover)\b/i, '@')
    gsub!(/\b(cont(rol)?|ctl|ctrl)\b/i, '^')
    gsub!(/\b(opt(ion)?|alt)\b/i, '~')
    gsub!(/\bshift\b/i, '$')
    gsub!(/\b(func(tion)?|fn)\b/i, '*')
    self
  end

  def clean_combo!
    replace(clean_combo)
  end

  def to_mod
    { '^' => "\u2303", '~' => "\u2325", '$' => "\u21E7", '@' => "\u2318", '*' => 'Fn' }.fetch(self, self)
  end

  def lower_to_upper
    {
      ',' => '<',
      '.' => '>',
      '/' => '?',
      ';' => ':',
      "'" => '"',
      '[' => '{',
      ']' => '}',
      '\\' => '|',
      '-' => '_',
      '=' => '+'
    }.fetch(self, self)
  end

  def upper?
    %w(< > ? : " { } | ! @ # $ % ^ & * \( \) _ +).include?(self)
  end

  def mod_to_title
    {
      "\u2303" => 'Control',
      "\u2325" => 'Option',
      "\u21E7" => 'Shift',
      "\u2318" => 'Command',
      'Fn' => 'Function'
    }.fetch(self, self)
  end
end

module KbdAutomator
  module Config
    CONFIG_PATH = File.expand_path('~/.config/kbd/config.yaml')
    DEFAULTS = {
      'kbd' => {
        'use_modifier_symbols' => true,
        'use_key_symbols' => true,
        'use_plus_sign' => false
      }
    }.freeze

    module_function

    def ensure!
      return if File.exist?(CONFIG_PATH)

      FileUtils.mkdir_p(File.dirname(CONFIG_PATH))
      File.write(CONFIG_PATH, default_yaml)
      system('open', CONFIG_PATH)
    end

    def load
      ensure!
      loaded = YAML.safe_load(File.read(CONFIG_PATH), permitted_classes: [], aliases: false) || {}
      deep_merge(DEFAULTS, loaded)
    rescue StandardError
      DEFAULTS
    end

    def default_yaml
      <<~YAML
        kbd:
          use_modifier_symbols: true
          use_key_symbols: true
          use_plus_sign: false
      YAML
    end

    def deep_merge(base, override)
      merged = base.dup
      override.each do |k, v|
        merged[k] =
          if v.is_a?(Hash) && base[k].is_a?(Hash)
            deep_merge(base[k], v)
          else
            v
          end
      end
      merged
    end
  end

  module CLI
    module_function

    def read_input(argv, stdin)
      return argv.join(' ').strip unless argv.empty?

      # In some non-interactive contexts stdin is not a TTY but has no data.
      # Use a zero-timeout select so we don't block waiting for input forever.
      return nil if stdin.tty? || IO.select([stdin], nil, nil, 0).nil?

      value = stdin.read.to_s.strip
      value.empty? ? nil : value
    end

    def print_help(script_name, io = $stderr)
      io.puts <<~HELP
        Usage:
          #{script_name} "shift cmd k"
          echo "shift cmd k" | #{script_name}

        Accepted input formats:
          - Symbol format: "$@k"
          - Text format: "shift cmd k"
          - Hyphenated text: "Shift-Command-k"
          - Multiple combos separated by: " / "

        Config file:
          #{Config::CONFIG_PATH}
      HELP
    end
  end

  class Formatter
    MOD_HTML = {
      "\u2303" => '&#8963;',
      "\u2325" => '&#8997;',
      "\u21E7" => '&#8679;',
      "\u2318" => '&#8984;',
      'Fn' => 'Fn'
    }.freeze
    MOD_TEXT = {
      "\u2303" => 'Control',
      "\u2325" => 'Option',
      "\u21E7" => 'Shift',
      "\u2318" => 'Command',
      'Fn' => 'Function'
    }.freeze
    KEY_MAP = {
      /^f(\d{1,2})$/ => ['F%<n>s', 'F%<n>s', 'F%<n>s'],
      /^apple$/ => ['Apple', "\uF8FF", 'Apple'],
      /^tab$/ => ['', "\u21E5", 'Tab'],
      /^caps(lock)?$/ => ['Caps Lock', "\u21EA", 'Caps Lock'],
      /^eject$/ => ['Eject', "\u23CF", 'Eject'],
      /^return$/ => ['Return', "\u21A9", 'Return'],
      /^enter$/ => ['Enter', "\u2324", 'Enter'],
      /^(del(ete)?|back(space)?)$/ => ['Del', "\u232B", 'Delete'],
      /^fwddel(ete)?$/ => ['Fwd Del', "\u2326", 'Forward Delete'],
      /^(esc(ape)?)$/ => ['Esc', "\u238B", 'Escape'],
      /^(right|rt)$/ => ['Right Arrow', "\u2192", 'Right Arrow'],
      /^(left|lt)$/ => ['Left Arrow', "\u2190", 'Left Arrow'],
      /^up$/ => ['Up Arrow', "\u2191", 'Up Arrow'],
      /^(down|dn)$/ => ['Down Arrow', "\u2193", 'Down Arrow'],
      /^pgup$/ => ['PgUp', "\u21DE", 'Page Up'],
      /^pgdn$/ => ['PgDn', "\u21DF", 'Page Down'],
      /^home$/ => ['Home', "\u2196", 'Home'],
      /^end$/ => ['End', "\u2198", 'End'],
      /^numlock$/ => ['Num Lock', "\u21ED", 'Num Lock'],
      /^clear$/ => ['Clear', "\u2327", 'Clear'],
      /^click$/ => ['click', "\u{1F5B1}", 'left click']
    }.freeze

    def initialize(use_modifier_symbols:, use_key_symbols:, use_plus_sign:)
      @use_modifier_symbols = use_modifier_symbols
      @use_key_symbols = use_key_symbols
      @use_plus_sign = use_plus_sign
    end

    def render_html(input)
      parse(input).map { |combo| combo_to_html(combo) }.reject(&:empty?).join('/')
    end

    def render_text(input)
      parse(input).map { |combo| combo_to_text(combo) }.reject(&:empty?).join('/')
    end

    private

    def parse(markup)
      markup.split(%r{ / }).map do |combo|
        mods = []
        key = +''
        combo = combo.dup
        combo.clean_combo!

        combo.strip.each_char do |char|
          next if char == ' '

          case char
          when /[\u2303\u21E7\u2325\u2318]/
            mods << char
          when /[*\^$@~]/
            mods << char.to_mod
          else
            key << char
          end
        end

        mods = sort_mods(mods)
        if key.length == 1
          mods << '$'.to_mod if mods.empty? && (key =~ /[A-Z]/ || key.upper?)
          key = key.lower_to_upper if mods.include?('$'.to_mod)
          key.upcase!
        elsif mods.include?('$'.to_mod)
          key = key.lower_to_upper
        end

        key.gsub!(/"/, '&quot;')
        { mods: mods, key: key }
      end
    end

    def sort_mods(mods)
      order = ['Fn', "\u2303", "\u2325", "\u21E7", "\u2318"]
      mods.uniq.sort { |a, b| order.index(a) < order.index(b) ? -1 : 1 }
    end

    def key_triplet(key)
      down = key.strip.downcase
      KEY_MAP.each do |pattern, val|
        next unless down.match?(pattern)

        if pattern == /^f(\d{1,2})$/
          num = down.match(pattern)[1]
          return [format(val[0], n: num), format(val[1], n: num), format(val[2], n: num)]
        end
        return val
      end
      [key, key, key.capitalize]
    end

    def combo_to_html(combo)
      return '' unless combo[:mods].any? || !combo[:key].empty?

      kbds = []
      title = []
      combo[:mods].each do |mod|
        mod_class = @use_modifier_symbols ? 'mod symbol' : 'mod'
        mod_text = @use_modifier_symbols ? MOD_HTML.fetch(mod, mod) : MOD_TEXT.fetch(mod, mod)
        kbds << %(<kbd class="#{mod_class}">#{mod_text}</kbd>)
        title << mod.mod_to_title
      end

      unless combo[:key].empty?
        key_name, key_symbol, key_title = key_triplet(combo[:key])
        key_class = @use_key_symbols ? 'key symbol' : 'key'
        key_content = @use_key_symbols ? key_symbol : key_name
        kbds << %(<kbd class="#{key_class}">#{key_content}</kbd>)
        title << key_title
      end

      sep = if @use_modifier_symbols
              @use_plus_sign ? '+' : ''
            else
              '-'
            end
      span_class = "keycombo #{@use_modifier_symbols && !@use_plus_sign ? 'combined' : 'separated'}"
      %(<span class="#{span_class}" title="#{title.join('-')}">#{kbds.join(sep)}</span>)
    end

    def combo_to_text(combo)
      return '' unless combo[:mods].any? || !combo[:key].empty?

      mods = combo[:mods].map do |mod|
        @use_modifier_symbols ? mod : MOD_TEXT.fetch(mod, mod)
      end

      key = ''
      unless combo[:key].empty?
        key_name, key_symbol, = key_triplet(combo[:key])
        key = @use_key_symbols ? key_symbol : key_name
      end

      pieces = mods + [key].reject(&:empty?)
      sep = if @use_modifier_symbols
              @use_plus_sign ? '+' : ''
            else
              '-'
            end
      pieces.join(sep)
    end
  end
end

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

puts formatter.render_text(input)
