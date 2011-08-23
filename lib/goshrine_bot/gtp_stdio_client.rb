# Provides a command line GTP interface
require 'timeout'

module GoshrineBot
  module GtpProcess
    def post_init
      @command_id = 0
      @results = Queue.new
      @cmd_queue = Queue.new
      @data = ""
    end
    
    def logfile=(logfile)
      @logfile = logfile
    end
    
    def log(str)
      File.open(@logfile, "a") do |f|
        f.write "#{Time.now} - #{str}\n"
      end
    end

    def send(command)
      @command_id += 1
      # if we're waiting on results, don't send data just yet; queue it.
      if @results.size > 0
        @cmd_queue.enq command
      else
        log "O: #{command.inspect}"
        send_data("#{command}\n")
      end
      res = EM::DefaultDeferrable.new
      @results.enq res
      res
    end
    
    def receive_data(data)
      log "I: #{data.inspect}"
      @data += data
      while (match_data = @data.match(/^([?=])(\d+)?\s(.*?)\n\n/m))      
        @data = @data[match_data[0].size..-1]

        res = @results.deq
        status = match_data[1]
        if status == '?'
          res.fail(match_data[3])
        else
          res.succeed(match_data[3])
        end
        if @cmd_queue.size > 0
          command = @cmd_queue.deq
          log "O: #{command.inspect}"
          send_data("#{command}\n")
        end
      end
    end
    
    def unbind
      log "gtp process exited with status: #{get_status.exitstatus.inspect}"
    end
  end
  
  class GtpStdioClient
    attr_accessor :command_id
    attr_accessor :boardsize
    attr_accessor :command_line
  
    def initialize(command_line, logfile="gtp.log")
      @command_line = command_line
      puts "Opening #{command_line.inspect}"
      @gtp = EM.popen(@command_line, GtpProcess, "args!")
      @gtp.logfile = logfile
      @logfile = logfile
      log "Starting #{command_line.inspect}"
    end

    def log(str)
      File.open(@logfile, "a") do |f|
        f.write "#{Time.now} - #{str}\n"
      end
    end
  
    def close
      log "Closing #{command_line.inspect}"
      @gtp.close_connection
    end
  
    def kill
      log "Kill #{command_line.inspect}"
      Process.kill 'TERM', @gtp.get_pid
    end
  
    def boardsize(size)
      @boardsize = size
      send("boardsize #{size}")
    end
  
    def play(color, move)
      #puts "Going to play #{color} #{move}"
      send("play #{color} #{move}")
    end

    def final_status_list(t)
      Timeout::timeout(10) do
        res = send("final_status_list #{t}")
        res.split.map {|c| Position.create(@boardsize, c)}
      end
    end
  
    def method_missing(methodname, *args)
      args = args.map {|a| a.to_s}.join(" ")
      send("#{methodname.to_s} #{args}")
    end
  
    private

    def gtp_color(rgo_color)
      if rgo_color == 'b'
        "black"
      elsif rgo_color == "w"
        "white"
      end
    end
  
    def send(command)
      @gtp.send(command)
    end
  end  
end

