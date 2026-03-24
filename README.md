# KBD Automator Actions

`kbd` turns keyboard shortcut text into consistently formatted output for
writing and documentation workflows, especially in Markdown and HTML.

![Demo](KBD.mp4)

Two command variants are included:

- `kbd.rb`: outputs HTML keycap markup (e.g. `<span class="keycombo ...">...</span>`)
- `kbd-text.rb`: outputs plain text shortcuts (using symbols or words based on config)

Both scripts accept the same input formats:

- Symbol format: `"$@k"`
- Text format: `"shift cmd k"`
- Hyphenated format: `"Shift-Command-k"`
- Multiple combos: `"shift cmd k / ctrl alt del"`

## Configuration

On first run, a config file is created at `~/.config/kbd/config.yaml`.

Available settings:

- `kbd.use_modifier_symbols` (default: `true`)
- `kbd.use_key_symbols` (default: `true`)
- `kbd.use_plus_sign` (default: `false`)

## Build Tasks

### Build self-contained scripts

Builds `dist/kbd.rb` and `dist/kbd-text.rb` with `kbd_automator_core.rb`
inlined and a `# version: x.y.z` comment inserted from `VERSION`.

```bash
rake build
```

### Build Automator actions archive

Builds `dist` scripts, injects script content into each workflow
`COMMAND_STRING`, signs each workflow, and creates `KBD Automator Actions.zip`.

```bash
rake build:automator
```

This uses:

- `automator/KBD HTML.workflow.template` <- `dist/kbd.rb`
- `automator/KBD Text.workflow.template` <- `dist/kbd-text.rb`

Generated/signed workflows are written to:

- `automator/Automator Actions/KBD HTML.workflow`
- `automator/Automator Actions/KBD Text.workflow`

Optional signing identity override:

```bash
SIGNING_ID="Apple Development: Your Name" rake build:automator
```

Or set your identity permanently in `Rakefile` by editing:

```ruby
SIGNING_ID = ENV.fetch('SIGNING_ID', 'Apple Development: Brett Terpstra')
```

For example, replace the default with your own certificate name:

```ruby
SIGNING_ID = ENV.fetch('SIGNING_ID', 'Apple Development: Your Name')
```

### Clean generated build output

```bash
rake clean
```

## Versioning

Current version is stored in `VERSION` (starting at `1.0.0`).

Increment version:

```bash
rake bump          # patch bump (default)
rake bump[patch]
rake bump[min]
rake bump[maj]
```

`rake bump` only updates the `VERSION` file.

## Deploy

Creates a release by bumping version, building/signing Automator workflows,
committing release artifacts, tagging, and creating a GitHub release with
`KBD Automator Actions.zip` attached.

```bash
rake deploy
rake deploy[patch]
rake deploy[min]
rake deploy[maj]
```

The deploy flow does:

1. `bump`
2. `build:automator`
3. `git add VERSION dist/`
4. `git commit -m "Release x.y.z"`
5. `git tag -a x.y.z -m "vx.y.z"` (or reuse existing local tag)
6. `git push origin refs/tags/x.y.z`
7. `changelog > release_notes.txt`
8. `gh release create x.y.z "KBD Automator Actions.zip" --notes-file release_notes.txt`
9. delete local `KBD Automator Actions.zip` after upload

## Installing the Automator Actions

1. Go to the [latest GitHub release](https://github.com/ttscoff/kbd/releases/latest).
2. Download `KBD Automator Actions.zip`.
3. Unzip the archive.
4. Double-click each `.workflow` file and install when prompted.

## Assigning Keyboard Shortcuts to Services

After installing, you can assign shortcuts to the Services in macOS:

1. Open System Settings.
2. Go to Keyboard.
3. Click Keyboard Shortcuts.
4. Select Services on the left.
5. Locate `Text -> KBD *`.
6. Click in the shortcut field to the right of the Service.
7. Press the shortcut you want to use.
