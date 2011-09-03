require 'rubygems'
require 'json'
require 'eventmachine'
require 'em-http'
require 'faye'
require 'logger'

module GoshrineBot

  VERSION = "0.1.9"

  STDOUT.sync = true
  
  ROOT = File.expand_path(File.dirname(__FILE__))
  
  %w[ client
      gtp_stdio_client
      runner
      game
      cookies
      faye_auth_ext
      core_ext/hash      
  ].each do |lib|
    require File.join(ROOT, 'goshrine_bot', lib)
  end

  #Faye.logger = Logger.new(STDOUT)
  #Faye::Logging.log_level = :debug

end
