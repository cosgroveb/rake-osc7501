# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'

RSpec.describe Rake::OSC7501::Run do
  let(:output) { StringIO.new }
  let(:run) { described_class.new(output, mode: 'force') }
  let(:task) { Struct.new(:name).new('compile') }

  it 'preserves results and reports a named indeterminate run' do
    expect(run.during_run { run.during_task(task) { 42 } }).to eq(42)
    records = frames(output.string)
    expect(records.map { |r| r['id'] }.uniq.size).to eq(1)
    expect(records.first['id']).to match(/\Arake-\d+-[a-f0-9]+\z/)
    expect(records.map { |r| r['msg'] }).to include('compile')
    expect(records.last['state']).to eq('done')
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
    expect(children).to all(start_with(frames(output.string).first['id'] + '/rspec-'))
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

  it 'allows managed children for non-TTY auto output but not off' do
    expect(described_class.new(output, mode: 'auto').managed_children?).to eq(true)
    expect(described_class.new(output, mode: 'off').managed_children?).to eq(false)
  end
end
