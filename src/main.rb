require 'io/console'
require './logcat'

class LogReader
  
  def initialize
    @break = false
    @mutex = Mutex.new
    @mutex.lock
    @filter = nil
    @pause = false
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
    log = Logcat.new
    log.reset "> Starting logcat.."
    while !@break do
      # TODO -b events

      @io = IO.popen "adb logcat", "r" do |io|
        io.each do |line|
          unless @pause
            log.process_line(line, @filter) unless @break
          else
            #TODO accumulate in buffer for later display
          end 
        end
      end
      @io.close if @io && !@io.closed?
    end
    log.reset "> Closing.."
  end

  #TODO
  def listen_user_input
    while 1
      char = STDIN.getch

      case char
      when 'q'
        @break = true
      when '0'
        @filter = nil
      when '1'
        @filter = :e
      when '2'
        @filter = :w
      when '3'
        @filter = :i
      when '4'
        @filter = :d
      when '5'
        @filter = :v
      when 's'
        @pause = !@pause
      end

      break if @break
    end

    close
  end

  def close
    @break = true
    if @mutex.locked?
      @mutex.unlock rescue nil
    end
    @io.close if @io && !@io.closed?
    @thread.exit
  end

end

reader = LogReader.new

for i in 1 .. 15  # SIGHUP .. SIGTERM
  if Signal.trap(i, "SIG_IGN") != 0 then  # 0 for SIG_IGN
    Signal.trap(i) do |signal|
      reader.close
      exit signal
    end
  end
end

reader.start
reader.listen_user_input


