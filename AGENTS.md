# Project guide

`rake-osc7501` is an opt-in OSC 7501 reporter for Rake tasks.
Target MRI Ruby >= 2.1 and Rake >= 12.3.3. Runtime dependencies stay limited to Rake.

- `lib/rake/osc7501.rb` activates reporting for Rake.
- `lib/rake/osc7501/` holds lifecycle hooks, writer and optional RSpec integration.
- `spec/rake/` covers runtime behavior and real subprocesses.
- `script/release.rb` and `spec/release_spec.rb` use modern Ruby only.

Run `bundle install`, then `bundle exec rake` for quality checks, specs,
installed-gem smoke tests and RDoc. Compatibility jobs use `Gemfile.compat`
and run `bundle exec rspec --options '' spec/rake`. The normal development bundle includes the
released RSpec companion. Set `RSPEC_OSC7501_PATH` with `BUNDLE_GEMFILE=Gemfile.integration` to test a local companion checkout.
Keep the `pure-rake` CI job independent of RSpec and the development bundle.

Preserve task scheduling, exceptions, exit status, configured RSpec formatters
and caller-owned streams. Keep records bounded and sanitize text. Do not add
process-wide exit hooks, signal handlers, terminal queries or worker aggregation.

All authored Ruby files and methods require inline RBS without blanket untyped
annotations. Keep type tools in modern development bundles. Do not commit gems,
HTML, lockfiles, bundle state or generated signatures. Preserve LICENSE verbatim.
Agent plans and designs belong in GBrain, never Git.

Pre-1.0, no API-stability promise. Two interfaces: the Ruby API
(require-time activation, preserved Rake behavior) and the emitted
escape sequences, which consumers parse. OSC 7501 frames must keep
conforming. Patch for fixes, minor for new behavior including added
sequences; removing or changing sequences is breaking.

Release with `script/release.rb prepare <version> <dir>`, build the gem,
then `publish <dir> <gem>`: the script handles the tag, the atomic main+tag
push, the RubyGems push and the GitHub release, then verifies the published
gem. If a release fails, inspect logs and rerun the same version to finish
missing steps. The first release uses the source version without a fabricated tag.
