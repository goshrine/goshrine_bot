module GoshrineBot

  class GoshrineRequest
    
    def self.base_url=(url)
      @@base_url = url
    end
    
    def initialize(path)
      @url = "#{@@base_url}#{path}"
      @conn = EventMachine::HttpRequest.new(@url)
      @cookie_persist = CookiePersist.new
    end
    
    def do_http(verb,options)
      puts "Sending"
      options[:head] = 
        {'Accept' => 'application/json', 
         'cookie' => @cookie_persist.cookie_hash.to_cookie_string}
  
      http = @conn.send verb, options
      
      defer = EM::DefaultDeferrable.new
      http.callback {
        puts "Persisting cookies"
        @cookie_persist.cookies << http.response_header[EM::HttpClient::SET_COOKIE]
        defer.succeed(http)
      }
      http.errback {
        puts "failed goshrine request"
        defer.fail(http)
      }
      defer
    end
    
    def post(options = {})
      do_http(:post, options)
    end
    
    def get(options = {})
      do_http(:get, options)
    end
  end
  
end
