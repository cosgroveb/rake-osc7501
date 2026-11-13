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

Run `bundle exec rake`. A supporting terminal receives the run as its root
record with task activity and the outcome. Each new run replaces it, and
ordinary command output continues.

## RSpec tasks

For managed child reporting, add `rspec-osc7501` 0.1.4 or newer and use the
standard RSpec task class. Either require order works:

```ruby
require 'rspec/core/rake_task'
require 'rake/osc7501'

RSpec::Core::RakeTask.new(:spec)
task default: [:example, :spec]
```

Each task invocation gets a unique child record, and a new run replaces only
the root record. Automatic selection preserves RSpec's configured formatters.
Missing or older `rspec-osc7501` installations leave the original RSpec
command intact, and direct `rspec` commands still need explicit OSC formatter
selection.

## Output controls

| Setting | Behavior |
| --- | --- |
| `RAKE_OSC7501=auto` | Default. Report to stdout only when it is a TTY and `TERM` is not `dumb`. |
| `RAKE_OSC7501=force` | Report to stdout even when redirected. |
| `RAKE_OSC7501=off` | Disable Rake reporting and automatic RSpec activation. |
| any other value | Raise `ArgumentError`. |

## Outcomes and limits

Normal completion reports `done`. Exceptions and nonzero `SystemExit` report
`error`, and `Interrupt` or early successful `SystemExit` report `idle`. The
gem leaves Rake's scheduling, exceptions and exit behavior intact. Frames stay
below 4096 bytes, and the gem sanitizes messages, caps them at 2048 decoded
bytes, installs no process-wide exit or signal hooks, and reads no terminal
input. Terminals control display, dismissal and notifications. We have not
verified live Rex presentation.

## Compatibility and development

Runtime targets MRI Ruby >= 2.1 and Rake >= 12.3.3, with an optional adapter
for RSpec >= 3.6. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full checks,
release setup and compatibility instructions.
