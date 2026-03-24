# KBD Automator Actions

`kbd` turns keyboard shortcut text into consistently formatted output for
writing and documentation workflows, especially in Markdown and HTML.

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
`COMMAND_STRING`, signs each workflow, and creates `Automator Actions.zip`.

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
`Automator Actions.zip` attached.

```bash
rake deploy
rake deploy[patch]
rake deploy[min]
rake deploy[maj]
```

The deploy flow does:

1. `bump`
2. `build:automator`
3. `git add VERSION dist/ "Automator Actions.zip"`
4. `git commit -m "Release x.y.z"`
5. `git tag x.y.z`
6. `gh release create x.y.z "Automator Actions.zip"`

## Installing the Automator Actions

1. Go to the latest GitHub release.
2. Download `Automator Actions.zip`.
3. Unzip the archive.
4. Double-click each `.workflow` file and install when prompted.
