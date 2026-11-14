# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'

RSpec.describe Rake::OSC7501::Run do
  let(:output) { StringIO.new }
  let(:run) { described_class.new(output, mode: 'force') }
  let(:task) { Struct.new(:name).new('compile') }

  it 'preserves results and reports a root record without identity' do
    expect(run.during_run { run.during_task(task) { 42 } }).to eq(42)
    records = frames(output.string)
    expect(records.map { |r| r['msg'] }).to include('compile')
    expect(records.last['state']).to eq('done')
    expect(records).to all(satisfy { |r| !r.key?('id') })
    expect(records).to all(satisfy { |r| !r.key?('progress') })
    expect(output).not_to be_closed
  end

  [RuntimeError.new('bad'), SystemExit.new(7), Interrupt.new, SystemExit.new(0)].each do |error|
    it "preserves #{error.inspect} and reports its outcome" do
      expect { run.during_run { run.during_task(task) { raise error } } }.to(raise_error do |actual|
        expect(actual).to equal(error)
      end)
      expected = error.is_a?(Interrupt) || (error.is_a?(SystemExit) && error.success?) ? 'idle' : 'error'
      expect(frames(output.string).last['state']).to eq(expected)
    end
  end

  it 'synchronizes parallel active tasks and unique child identifiers' do
    started = Queue.new
    release = Queue.new
    ids = Queue.new
    run.during_run do
      workers = 2.times.map do
        Thread.new do
          run.during_task(task) do
            ids << run.next_child_id
            started << true
            release.pop
          end
        end
      end
      2.times { started.pop }
      2.times { release << true }
      workers.each(&:join)
    end
    expect(frames(output.string).map { |r| r['msg'] }).to include('2 active tasks')
    children = 2.times.map { ids.pop }
    expect(children.uniq.size).to eq(2)
    expect(children).to all(match(/\Arake-\d+-[a-f0-9]+\/rspec-\d+\z/))
    prefixes = children.map { |id| id.split('/').first }.uniq
    expect(prefixes.size).to eq(1)
  end

  it 'assigns distinct child prefixes across successive runs' do
    second = described_class.new(output, mode: 'force')
    prefixes = [run, second].map do |active|
      active.next_child_id.split('/').first
    end
    expect(prefixes.uniq.size).to eq(2)
    [run, second].each do |active|
      active.during_run {}
    end
    records = frames(output.string)
    expect(records.select { |r| r['state'] != 'working' }).to all(satisfy { |r| !r.key?('id') })
    expect(records.select { |r| r['state'] != 'working' }.map { |r| r['state'] }).to eq(%w[done done])
  end

  it 'does not overwrite the final outcome when another task unwinds later' do
    entered = Queue.new
    release = Queue.new
    worker = nil
    begin
      expect do
        run.during_run do
          worker = Thread.new do
            run.during_task(task) do
              entered << true
              release.pop
            end
          end
          entered.pop
          raise 'failed task'
        end
      end.to raise_error('failed task')
    ensure
      release << true
      worker.join if worker
    end
    expect(frames(output.string).last['state']).to eq('error')
  end

  it 'titles the run and the single active task' do
    run.during_run { run.during_task(task) { true } }
    expect(titles(output.string)).to eq(['rake', 'rake › compile', 'rake', 'rake'])
  end

  it 'names the outer task again when a nested task finishes' do
    other = Struct.new(:name).new('package')
    run.during_run { run.during_task(task) { run.during_task(other) { true } } }
    expect(titles(output.string))
      .to eq(['rake', 'rake › compile', 'rake › 2 active tasks', 'rake › compile', 'rake', 'rake'])
  end

  it 'presents parallel active tasks by count and restores the remaining task' do
    started = Queue.new
    release = Queue.new
    workers = []
    begin
      run.during_run do
        workers = %w[compile package].map do |name|
          Thread.new do
            run.during_task(Struct.new(:name).new(name)) do
              started << true
              release.pop
            end
          end
        end
        2.times { started.pop }
        2.times { release << true }
        workers.each(&:join)
      end
    ensure
      workers.each { |worker| worker.join if worker.alive? }
    end
    sequence = titles(output.string)
    expect(sequence.count('rake › 2 active tasks')).to eq(1)
    expect(sequence.first).to eq('rake')
    expect(sequence.last(2)).to eq(%w[rake rake])
    expect(sequence.count { |title| title.start_with?('rake › ') && title != 'rake › 2 active tasks' }).to eq(2)
  end

  [RuntimeError.new('bad'), SystemExit.new(7), Interrupt.new, SystemExit.new(0)].each do |error|
    it "restores the idle title after #{error.inspect}" do
      expect { run.during_run { run.during_task(task) { raise error } } }.to raise_error(error.class)
      expect(titles(output.string).last).to eq('rake')
      expect(titles(output.string)).to include('rake › compile')
    end
  end

  it 'restores the idle title when a task exits successfully' do
    expect { run.during_run { run.during_task(task) { exit 0 } } }.to raise_error(SystemExit)
    expect(titles(output.string).last).to eq('rake')
    expect(frames(output.string).last['state']).to eq('idle')
  end

  it 'sanitizes task names in titles' do
    hostile = Struct.new(:name).new("\e]0;pwn\a\n".b.force_encoding('UTF-8'))
    run.during_run { run.during_task(hostile) {} }
    expect(titles(output.string)).to include('rake › ]0;pwn')
    expect(titles(output.string)).to all(satisfy { |title| title !~ /[\u0000-\u001F\u007F-\u009F]/ })
  end

  it 'runs a task whose name is malformed binary' do
    binary = Struct.new(:name).new("\xFF report\n".b)
    expect(run.during_run { run.during_task(binary) { 42 } }).to eq(42)
    expect(titles(output.string)).to include("rake › \ufffd report")
    expect(titles(output.string)).to all(satisfy { |title| title.valid_encoding? && title !~ /[\u0000-\u001F\u007F-\u009F]/ })
    expect(frames(output.string).last['state']).to eq('done')
  end

  it 'stops writing titles once the output stream fails' do
    output.close
    expect { run.during_run { run.during_task(task) { true } } }.not_to raise_error
    expect(output.string).to be_empty
  end

  it 'allows managed children for non-TTY auto output but not off' do
    expect(described_class.new(output, mode: 'auto').managed_children?).to eq(true)
    expect(described_class.new(output, mode: 'off').managed_children?).to eq(false)
  end
end
