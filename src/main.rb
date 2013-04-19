require 'io/console'
require './logcat'

class LogReader
  
  def initialize

  end

  def pick_device
    @device = nil
    result = `adb devices`

    if result
      devices = []
      devices_result = result.strip.split("\n")
      devices_result.each do |dr|
        device = dr.split("\t")
        if device.size == 2 && device[1] == "device"
          devices << device.first
        end
      end

      if devices.size > 0
        if devices.size == 1
          @device = devices.first
        else
          puts "Choose device:"
          devices.each_with_index do |dev, index|
            puts "#{index+1}. #{dev}"
          end

          choice = gets.to_i

          if choice >= 1 && choice <= devices.size
            @device = devices[choice - 1]
            puts "\nYour choice: #{@device}"
          else
            puts "Wrong choice!!!"
          end
        end
      end
    end

    @device
  end

  def init
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
    init
    @mutex.unlock
  end

  # read from adb
  def run
    log = Logcat.new
    log.reset "> Starting logcat for device: #{@device}.."
    while !@break do
      # TODO -b events

      @io = IO.popen "adb -s #{@device} logcat", "r" do |io|
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

if reader.pick_device
  reader.start
  reader.listen_user_input
end


