# rake-osc7501

Add OSC 7501 terminal status to ordinary Rake tasks.

```ruby
# Gemfile
gem 'rake-osc7501'
```

```ruby
# Rakefile
require 'rake/osc7501'

task(:example) { sleep 5 }
task default: :example
```

Run `bundle exec rake`. A supporting terminal receives the overall Rake run as
its root record, with task activity and the command's outcome. Each new Rake
run replaces that root record. Ordinary command output continues.
Rake-only projects need no RSpec dependencies.

## RSpec tasks

Add `rspec-osc7501` 0.1.4 or newer for managed child reporting:

```ruby
gem 'rspec-osc7501', '>= 0.1.4'
```

Run `bundle install`, then load the standard RSpec task class before this integration:

```ruby
require 'rspec/core/rake_task'
require 'rake/osc7501'

RSpec::Core::RakeTask.new(:spec)
task(:example) { sleep 5 }
task default: [:example, :spec]
```

Existing and later-created standard tasks receive a unique child record for each
invocation. Child records keep their own identities, so each new Rake run
replaces only the root record and previously finished children may remain until
the terminal retires them.
Automatic selection preserves RSpec's default progress formatter and
configured formatters, including their output files. An explicit OSC formatter
keeps its destination and receives no duplicate.

Missing or older `rspec-osc7501` installations without `rspec/osc7501/managed.rb`
leave the original RSpec command intact. Either require order works when RSpec's
Rake tasks are loaded before top-level execution. Custom runners receive generic
Rake reporting. Direct `rspec` commands still need explicit OSC
formatter selection.

The adapter passes child context through the spawn environment. It preserves
parent environment variables and task options. RSpec's clean-environment option,
where available, receives only the child ID and explicit `RSPEC_OSC7501`,
`RSPEC_OSC7501_TITLE`, and `TERM` controls.

## Output controls

| Setting | Behavior |
| --- | --- |
| `RAKE_OSC7501=auto` | Default. Report to stdout only when it is a TTY and `TERM` is not `dumb`. |
| `RAKE_OSC7501=force` | Report to stdout even when redirected. |
| `RAKE_OSC7501=off` | Disable Rake reporting and automatic RSpec activation. |

Other values raise `ArgumentError`. Explicit RSpec selections retain their own
`RSPEC_OSC7501` controls. Automatic child activation does not depend on the
parent's TTY because each child honors its RSpec-selected stream.

## Outcomes and limits

Rake reports active task actions without a percentage. Overlapping actions show
an active count. Skipped file tasks, deduplicated invocations, task listings and
dry runs do not report executed work.

Normal completion reports `done`. Exceptions and nonzero `SystemExit` report
`error`. `Interrupt` and successful early `SystemExit` report `idle`. Reporting
preserves Rake's scheduling, exceptions and exit behavior.

Child results remain after the child and parent finish. A passing suite followed
by a failing Rake task retains the passing child and failed parent. With
`fail_on_error = false`, a failed child can accompany a successful parent.
No completion clears records.

Rake covers task execution after activation. Failures before activation or in
later process-exit handlers fall outside that result. Abrupt child termination
can leave a working record without a summary. A child summary can precede a
process failure. Rake reports the process outcome without inventing test results.

Frames stay below 4096 bytes. Messages contain sanitized UTF-8, capped at 2048
decoded bytes. Stream errors disable reporting without closing caller streams.
The gems install no process-wide exit or signal hooks and read no terminal input.
Terminals control display, dismissal and notifications. Live Rex presentation
has not been verified.

## Compatibility and development

Runtime targets MRI Ruby >= 2.1 and Rake >= 12.3.3. The optional adapter targets
RSpec >= 3.6. The oldest paired check uses Ruby 2.1.10, Rake 12.3.3 and RSpec 3.6.0.
Linux checks also cover Ruby 2.7, 3.1, 3.3, 3.4 and 4.0 with compatible RSpec
versions, including RSpec 4.0.0.beta1 on Ruby 4.0. RSpec 3.6 has no
clean-environment option. CI also checks macOS with Ruby 3.4.
Other Ruby engines are unverified.

On modern Ruby:

```sh
bundle install
bundle exec rake
bundle exec rake spec
```

The development bundle includes the RSpec companion, so the normal suite exercises
both reporters. The `pure-rake` CI job checks passing and failing tasks with only
Rake and the built gem installed in an isolated gem directory.
Set `RSPEC_OSC7501_PATH` to test a local companion checkout instead of the released gem.

`rake types` checks method annotation coverage across authored Ruby files,
generates inline RBS, and uses Steep to check implementations in `lib/` and
`script/` against their signatures. Specs and build configuration receive
annotation and signature validation, not implementation checking.
Generated project signatures stay in ignored `tmp/`. `sig/dependencies.rbs`
supplies missing dependency declarations. See [CONTRIBUTING.md](CONTRIBUTING.md)
for lint, dependency audit, workflow checks and release setup. Compatibility checks use `Gemfile.compat`
without type tooling. Pass an RSpec gem package as the smoke script's second
argument to check installed parent/child reporting.
