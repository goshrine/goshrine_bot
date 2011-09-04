require 'uri'

module GoshrineBot

  class Client

    class << self
    end

    def initialize(options)
      @base_url = URI::parse(options[:server_url])
      @options = options
      @password = options[:password]
      @login = options[:login]
      @gtp_cmd_line = options[:gtp_cmd_line]
      @connected = false
      @games = {}
    end
    
    def gtp_cmd_line
      @gtp_cmd_line
    end
    
    def my_user_id
      @my_user_id
    end
    
    def login(&blk)
      # login
      http = http_post('/sessions/create', {'login' => @login, 'password' => @password})
      http.callback {
        if http.response_header.status == 401
          puts "Invalid Login or Password"
          EventMachine::stop
        else
          user = JSON.parse(http.response)
          puts "Got #{user.inspect}"
          @queue_id = user['queue_id']
          @my_user_id = user['id']
          @faye_token = user['faye_token']
          if user['user_type'] != 'bot'
            puts "Account #{user['login']} is not registered as a robot!"
            EventMachine::stop
          else
            puts "Login successful"
            blk.call
          end
        end
      }
      http.errback {|response|
        puts "Login failed (network issue?)";
      }
    end
    
    def http_post(path, data = nil)
      conn = EM::HttpRequest.new("#{@base_url}#{path}")
      conn.use CookiePersist
      headers = {'Accept' => 'application/json'}
      
      http = conn.post(:head => headers, :body => data)
      
      http.headers { |head|
        CookiePersist.cookies << head[EM::HttpClient::SET_COOKIE]
      }
      http
    end

    def http_get(path)
      conn = EM::HttpRequest.new("#{@base_url}#{path}")
      conn.use CookiePersist
      
      http = conn.get(:head => {'Accept' => 'application/json'})
      
      http.headers { |head|
        CookiePersist.cookies << head[EM::HttpClient::SET_COOKIE]
      }
      http
    end
    
    def subscribe
      @faye_client.subscribe("/user/private/" + @queue_id) do |m|
        msg_type = m["type"]
        case msg_type
        when 'match_requested'
          handle_match_request(m["match_request"])
        when 'match_accepted'
          handle_match_accept(m["game_token"])
        else
          puts "Unsupported private message type: #{msg_type}"
        end
        #@msg_queue_in.push(doc)
      end
      @faye_client.subscribe("/room/1") do |m|
        #@msg_queue_in.push(doc)
      end
    end

    def run
      login {
        puts "Starting faye client"
        @faye_client = Faye::Client.new((@base_url + '/events').to_s, :cookie => @cookie)
        if @faye_token
          @faye_client.add_extension(FayeAuthExt.new(@my_user_id, @faye_token))
        end
        subscribe          
        load_existing_games {
          if @options[:idle_shutdown_timeout] > 0
            EM::add_periodic_timer( @options[:idle_shutdown_timeout] ) {
              @games.each do |token, game|
                game.idle_check(@options[:idle_shutdown_timeout])
              end
            }
          end
        }
      }
    end

    def load_existing_games(&blk)
      http = http_get('/game/active')
      http.callback {
        #puts "Got #{response.inspect}"
        games = JSON.parse(http.response)
        puts "#{games.count} game(s) in progress"
        games.each do |game_attrs|
          game = GameInProgress.new(self)
          game.update_from_game_list(game_attrs)
          if game.move_number != game.moves.size
            puts "Only #{game.moves.size} available! Expected #{game.move_number} in game #{game.token}"
          else
            add_game(game)
          end
        end
        blk.call
      }
    end
    
    def add_game(game)
      @games[game.game_id] = game
      game.make_move # does nothing if its not our turn, or the game is not started
      @faye_client.subscribe("/game/private/" + game.token + '/' + @queue_id) do |m|
        game.private_message(m)
      end
      @faye_client.subscribe("/game/play/" + game.token) do |m|
        game.play_message(m)
      end
    end

    def handle_match_accept(token)
      game = GameInProgress.new(self)
      http = http_get("/g/#{token}")
      http.callback {
        attrs = JSON.parse(http.response)
        game.update_from_game_list(attrs)
        add_game(game)
      }      
    end
    
    def handle_match_request(request)
      active_games = @games.select { |key, game| game.state == "in-play" }
      max_games = @options[:maximum_concurrent_games]
      game = GameInProgress.new(self)
      game.update_from_match_request(request)
      if max_games.nil? || active_games.count < max_games
        http = http_get("/match/accept?id=#{game.challenge_id}")
        http.callback {
          attrs = JSON.parse(http.response)
          game.update_from_game_list(attrs)
          add_game(game)
        }
      else 
        count = max_games > 1 ? "#{max_games} games" : "1 game"
        reason = "#{@login} only plays #{count} at a time."
        puts "Rejecting match: #{reason}"
        http = http_get("/match/reject?id=#{game.challenge_id}&reason=#{URI.escape(reason)}")
      end
    end
    
  end
end

