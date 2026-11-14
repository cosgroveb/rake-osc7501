# frozen_string_literal: true
# rbs_inline: enabled

require 'spec_helper'

RSpec.describe Rake::OSC7501::Writer do
  let(:output) { StringIO.new }

  it 'bounds and sanitizes text without identity, progress or closing the stream' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: "\xFF\n".b.force_encoding('UTF-8') + '界' * 3000)
    record = frames(output.string).first
    expect(record).to include('app' => 'rake', 'title' => 'Rake')
    expect(record).not_to have_key('id')
    expect(record['msg'].bytesize).to be <= 2048
    expect(record['msg']).to be_valid_encoding
    expect(record['msg']).not_to match(/[\u0000-\u001F\u007F-\u009F]/)
    expect(output.string.bytesize).to be <= 4096
    expect(record).not_to have_key('progress')
    expect(output).not_to be_closed
  end

  it 'ends each frame with exactly one terminator and no trailing bytes' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'done', msg: 'Completed')
    expected = "\e]2;rake\e\\\e]7501;app=rake:title=UmFrZQ==:state=done:msg=Q29tcGxldGVk\e\\"
    expect(output.string).to eq(expected)
  end

  it 'replaces the terminal title immediately before each status frame' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: 'compile', window_title: 'compile')
    expected_title = "\e]2;rake › compile\e\\"
    expected_frame = "\e]7501;app=rake:title=UmFrZQ==:state=working:msg=Y29tcGlsZQ==\e\\"
    expect(output.string).to eq(expected_title + expected_frame)
  end

  it 'sanitizes titles the same way as messages' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: 'compile',
                window_title: "\e\xFF\n".b.force_encoding('UTF-8') + "\a界" * 3000)
    title = titles(output.string).first
    expect(title).to be_valid_encoding
    expect(title).not_to match(/[\u0000-\u001F\u007F-\u009F]/)
    expect(title).to start_with('rake › ')
    expect(title.bytesize).to be <= 512
    expect(frames(output.string).first['msg']).to eq('compile')
    expect(output.string.scan("\e\\").size).to eq(frames(output.string).size + titles(output.string).size)
  end

  it 'bounds the whole title and keeps the last complete character' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: 'ok', window_title: 'a' * 510 + '界界')
    title = titles(output.string).first
    expect(title.bytesize).to eq(512)
    expect(title).to eq('rake › ' + 'a' * 503)
  end

  it 'titles the run alone when the task name sanitizes empty' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: 'ok', window_title: "\e\n\u0000")
    expect(titles(output.string)).to eq(['rake'])
  end

  it 'titles the run alone when no task name is given' do
    writer = described_class.new(output, mode: 'force')
    writer.emit(state: 'working', msg: 'ok')
    expect(titles(output.string)).to eq(['rake'])
    expect(output.string).to eq("\e]2;rake\e\\\e]7501;app=rake:title=UmFrZQ==:state=working:msg=b2s=\e\\")
  end

  it 'rejects invalid modes' do
    expect { described_class.new(output, mode: 'bad') }.to raise_error(ArgumentError)
  end

  it 'silences non-TTY auto output' do
    described_class.new(output, mode: 'auto').emit(state: 'done', msg: 'ok', window_title: 'rake')
    expect(output.string).to be_empty
  end

  it 'silences a dumb terminal even when TTY' do
    allow(output).to receive(:tty?).and_return(true)
    allow(ENV).to receive(:[]).with('TERM').and_return('dumb')
    described_class.new(output, mode: 'auto').emit(state: 'done', msg: 'ok', window_title: 'rake')
    expect(output.string).to be_empty
  end

  it 'contains closed-stream errors' do
    output.close
    writer = described_class.new(output, mode: 'force')
    expect { writer.emit(state: 'done', msg: 'ok', window_title: 'rake') }.not_to raise_error
  end

  it 'contains broken pipes without closing the stream' do
    reader, stream = IO.pipe
    begin
      reader.close
      writer = described_class.new(stream, mode: 'force')
      expect do
        2.times { writer.emit(state: 'done', msg: 'ok', window_title: 'rake') }
      end.not_to raise_error
      expect(stream).not_to be_closed
    ensure
      stream.close
    end
  end
end
