require 'optparse'
require 'yaml'
require 'erb'

module GoshrineBot
  class Runner
    attr_accessor :options
    
    class << self
      def run
        self.new
      end
    end
    
    def initialize
      # defaults
      self.options = {
        :server_url => "http://goshrine.com/",
        :gtp_cmd_line => "gnugo --mode gtp",
        :debug => false,
        :idle_shutdown_timeout => 60,
        :pid_path => "./goshrine_bot.pid",
        :log_path => "./goshrine_bot.log",
      }
      
      cmd_line_options = parse_options
      
      if !File.exists?(config_path)
        puts "You must generate a config file."
        exit
      end
      
      config = YAML::load(ERB.new(IO.read(config_path)).result)
      #puts "config = #{config.inspect}"
      bot_name = ARGV[0] || config.keys.first
      #puts "bot_name = #{ARGV[0]}"
      if config[bot_name].nil?
        puts "No config found for #{bot_name.inspect}"
        exit
      end
      options.merge!(config[bot_name])
      #puts "Options = #{options.inspect}"
      options[:bot_name] = bot_name
      
      start
    end
    
    def config_path
      options[:config_path] || "./goshrine_bot.yml"
    end
    
    def start
      puts "Starting GoShrine (v#{GoshrineBot::VERSION}) bot client: #{options[:bot_name]}."
      
      client = Client.new(options)
      client.run      
    end
    
    def parse_options
      OptionParser.new do |opts|
        opts.summary_width = 25
        opts.banner = "GoShrineBot (1.0)\n\n",
                      "Usage: goshrine_bot [-c configfile] [bot_name]\n",
                      "       goshrine_bot --help\n"
        
        opts.separator ""
        opts.separator ""; opts.separator "Configuration:"
        
        opts.on("-c", "--config FILE", String, "Path to configuration file.", "(default: #{options[:config_path]})") do |v|
          options[:config_path] = File.expand_path(v)
        end
        
        opts.separator ""; opts.separator "Miscellaneous:"
        
        opts.on_tail("-?", "--help", "Display this usage information.") do
          puts "#{opts}\n"
          exit
        end
        
      end.parse!
      options
    end
    
    private
    
    def store_pid(pid)
      FileUtils.mkdir_p(File.dirname(pid_path))
      File.open(pid_path, 'w'){|f| f.write("#{pid}\n")}
    end
    
  end
end
