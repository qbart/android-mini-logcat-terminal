require './log_cat'

class LogReader

  def initialize
    @break = false
    @mutex = Mutex.new
    @mutex.lock
    @thread = Thread.new do
      @mutex.lock
      run unless @break
    end
  end

  def start
    @mutex.unlock
  end

  # read from adb
  def run
    log = LogCat.new
    while !@break do
      # TODO -b events
      puts "Starting logcat.."
      @io = IO.popen "adb logcat" do |io|
        io.each do |line|
          log.process_line(line) unless @break
        end
      end
      @io.close if @io && !@io.closed?
    end
    puts "Closing.."
  end

  #TODO
  def listen_user_input
    loop do
      break if @break
    end
  end

  def close
    @break = true
    if @mutex.locked?
      @mutex.unlock rescue nil
    end
    @io.close if @io && !@io.closed?
    @thread.join
  end

end

reader = LogReader.new

%w(INT TERM QUIT).each do |signal|
  Signal.trap(signal) do
    reader.close
  end
end

reader.start
reader.listen_user_input


