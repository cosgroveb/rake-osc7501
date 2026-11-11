# frozen_string_literal: true
# rbs_inline: enabled

require 'open3'
require 'tmpdir'
require 'rbconfig'
require 'fileutils'
require 'pty'

class RakeSuite
  #: (String, ?Array[String], ?Hash[String, String?], ?Hash[String, String], ?bool) -> [String, String, Process::Status, Hash[String, String]]
  def self.run(source, arguments = [], environment = {}, files = {}, tty = false)
    Dir.mktmpdir('rake osc7501 ') do |directory|
      File.write(File.join(directory, 'Rakefile'), source)
      files.each do |name, text|
        path = File.join(directory, name)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text)
      end
      env = { 'RAKE_OSC7501' => 'force', 'RSPEC_OSC7501' => 'force', 'RSPEC_OSC7501_ID' => nil,
              'TERM' => nil }.merge(environment)
      command = [RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-S', 'rake', *arguments]
      output, error, status = tty ? capture_tty(env, command, directory) : capture(env, command, directory)
      results = Dir[File.join(directory, '*.out')].each_with_object({}) { |path, result| result[File.basename(path)] = File.read(path) }
      [output, error, status, results]
    end
  end
  #: (Hash[String, String?], Array[String], String) -> [String, String, Process::Status]
  def self.capture(environment, command, directory)
    Open3.popen3(environment, *command, chdir: directory, pgroup: true) do |input, output, error, waiter|
      input.close
      readers = [output, error].map { |stream| Thread.new { stream.read } }
      begin
        raise 'Rake subprocess timeout' unless waiter.join(15)
        [readers[0].value, readers[1].value, waiter.value]
      ensure
        unless waiter.join(0)
          Process.kill('KILL', -waiter.pid)
          waiter.join
        end
        readers.each(&:join)
      end
    end
  end

  #: (Hash[String, String?], Array[String], String) -> [String, String, Process::Status]
  def self.capture_tty(environment, command, directory)
    master, slave = PTY.open
    pid = Process.spawn(environment, *command, chdir: directory, out: slave, err: slave, pgroup: true)
    slave.close
    output = String.new
    status = nil
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    begin
      loop do
        if IO.select([master], nil, nil, 0.05)
          begin
            output << master.read_nonblock(65_536)
          rescue IO::WaitReadable
            next
          rescue EOFError, Errno::EIO
            break
          end
        end
        raise 'Rake PTY timeout' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end
      _, status = Process.waitpid2(pid)
      [output, '', status]
    ensure
      unless status
        Process.kill('KILL', -pid)
        Process.waitpid(pid)
      end
      master.close
    end
  end
end
