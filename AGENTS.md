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
released RSpec companion. Set `RSPEC_OSC7501_PATH` to test a local companion checkout.
Keep the `pure-rake` CI job independent of RSpec and the development bundle.

Preserve task scheduling, exceptions, exit status, configured RSpec formatters
and caller-owned streams. Keep records bounded and sanitize text. Do not add
process-wide exit hooks, signal handlers, terminal queries or worker aggregation.

All authored Ruby files and methods require inline RBS without blanket untyped
annotations. Keep type tools in modern development bundles. Do not commit gems,
HTML, lockfiles, bundle state or generated signatures. Preserve LICENSE verbatim.
Agent plans and designs belong in GBrain, never Git.

If a release fails, inspect logs and rerun the same version to finish missing
steps. The first release uses the source version without a fabricated tag.
