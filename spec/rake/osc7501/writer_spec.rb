# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'

RSpec.describe Rake::OSC7501::Writer do
  let(:output) { StringIO.new }

  it 'bounds and sanitizes text without progress or closing the stream' do
    writer = described_class.new(output, mode: 'force', id: 'rake-1-a')
    writer.emit(state: 'working', msg: "\xFF\n".b.force_encoding('UTF-8') + '界' * 3000)
    record = frames(output.string).first
    expect(record).to include('app' => 'rake', 'title' => 'Rake', 'id' => 'rake-1-a')
    expect(record['msg'].bytesize).to be <= 2048
    expect(record['msg']).to be_valid_encoding
    expect(record['msg']).not_to match(/[\u0000-\u001F\u007F-\u009F]/)
    expect(output.string.bytesize).to be <= 4096
    expect(record).not_to have_key('progress')
    expect(output).not_to be_closed
  end

  it 'silences invalid IDs' do
    described_class.new(output, mode: 'force', id: 'bad:id').emit(state: 'done', msg: 'ok')
    expect(output.string).to be_empty
  end

  it 'rejects invalid modes' do
    expect { described_class.new(output, mode: 'bad', id: 'rake-1-a') }.to raise_error(ArgumentError)
  end

  it 'silences non-TTY auto output' do
    described_class.new(output, mode: 'auto', id: 'rake-1-a').emit(state: 'done', msg: 'ok')
    expect(output.string).to be_empty
  end

  it 'silences a dumb terminal even when TTY' do
    allow(output).to receive(:tty?).and_return(true)
    allow(ENV).to receive(:[]).with('TERM').and_return('dumb')
    described_class.new(output, mode: 'auto', id: 'rake-1-a').emit(state: 'done', msg: 'ok')
    expect(output.string).to be_empty
  end

  it 'contains closed-stream errors' do
    output.close
    writer = described_class.new(output, mode: 'force', id: 'rake-1-a')
    expect { writer.emit(state: 'done', msg: 'ok') }.not_to raise_error
  end

  it 'contains broken pipes without closing the stream' do
    reader, stream = IO.pipe
    begin
      reader.close
      writer = described_class.new(stream, mode: 'force', id: 'rake-1-a')
      expect { 2.times { writer.emit(state: 'done', msg: 'ok') } }.not_to raise_error
      expect(stream).not_to be_closed
    ensure
      stream.close
    end
  end
end
