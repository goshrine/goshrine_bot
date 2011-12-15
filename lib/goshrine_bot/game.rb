module GoshrineBot
  class GameInProgress
    attr_accessor :state
    attr_accessor :board_size
    attr_accessor :proposed_by_id
    attr_accessor :white_player_id
    attr_accessor :black_player_id
    attr_accessor :challenge_id
    attr_accessor :token
    attr_accessor :game_id
    attr_accessor :gtp_client
    attr_accessor :move_number
    attr_accessor :turn
    attr_accessor :komi
    attr_accessor :moves
    attr_accessor :handicap
    attr_accessor :handicap_stones
    attr_accessor :last_activity
    
    def initialize(client)
      @client = client
    end
        
    def play_message(m)
      return unless m
      #puts "Got game play message: #{m.inspect}"
      case m["action"]
      when 'user_arrive'
        user_id = m["id"].to_i
        puts "User arrived (#{token}): #{m["login"]}"
        if state == 'new' && (user_id == black_player_id || user_id == white_player_id)
          GoshrineRequest.new("/game/#{token}/attempt_start").post
        end
      when 'game_started'
        self.state = "in-play"
        make_move
      when 'updateBoard'
        handle_move(m["data"])
        #puts "Going to update board"
      when 'resignedBy'
        puts "Game resigned by opponent."
        self.state = "finished"
        stop_gtp_client
      when 'updateForUndo'
        # TODO - handle undos?
        puts "Undo not currently supported"
      when 'pleaseWait'
        # ignore
      when 'user_leave'
        # ignore
      when 'gameFinished'
        stop_gtp_client
        self.state = "finished"
        if m['data'].nil?
          puts "Missing data: #{m.inspect}"
          return
        elsif m['data']['scoring_info'].nil?
          puts "Missing scoring_info: #{m.inspect}"
          return
        end
        score = m['data']['scoring_info']['score']
        winner = score['black'] > score['white'] ? 'B' : 'W'
        if my_color == winner
          puts "I Won!"
        else
          puts "I Lost."
        end
        puts "Score: #{score.inspect}"
      else
        puts "Unhandled game play message #{m.inspect}"
      end
    end
    
    def handle_move(m)
      # {"captures"=>[], "move_number"=>1, "color"=>"b", "move"=>"ir", "black_seconds_left"=>1900, "white_seconds_left"=>1900, "turn_started_at"=>"Sat, 05 Dec 2009 00:44:19 -0600"}
      pos = m["move"]
      color = m["color"].upcase
      if pos && color && color != my_color
        pos = sgf_coord_to_gtp_coord(pos, board_size)
        puts "Received move #{pos}"
        gtp_client.time_left("B", m["black_seconds_left"], 0).callback {
          gtp_client.time_left("W", m["white_seconds_left"], 0).callback {
            gtp_client.play(color, pos).callback {
              self.moves << [color, pos]
              self.move_number = m["move_number"].to_i
              self.turn = m["color"] == "b" ? "w" : "b"
              make_move
            }
          }
        }
      end
    end
    
    def idle_check(timeout)
      if timeout > 0 && @last_gtp_access && @last_gtp_access + timeout < Time.now
        puts "Shutting down gtp client #{self.token} after #{timeout} seconds idle."
        stop_gtp_client
      end
    end
        
    def private_message(m)
      puts "Got private game message: #{m.inspect}"
      case m["type"]
      when 'undo_requested'
        GoshrineReuqest.new("/game/accept_undo/" + m["request_id"]).post
      end
    end
    
    def handle_messages
      msg = @queue.pop
      args = msg[1..-1]
      self.send(msg.first, *args)
    end
    
    def my_turn?
      @client.my_user_id == players_turn
    end
    
    def started?
      state != 'new'
    end
    
    def update_from_match_request(attrs)
      self.state = attrs['state']
      self.board_size = attrs['board_size'].to_i
      self.proposed_by_id = attrs['proposed_by_id'].to_i
      self.white_player_id = attrs['white_player_id'].to_i
      self.black_player_id = attrs['black_player_id'].to_i
      self.challenge_id = attrs['id'].to_i
      self.handicap = attrs['handicap'].to_i
      self.handicap_stones = attrs['handicap_stones']
      self.turn = handicap > 1 ? 'w' : 'b'
      self.move_number = 0
      self.moves = []
    end
    
    def update_from_game_list(attrs)
      #puts "attrs = #{attrs.inspect}"
      self.state = attrs['state']
      self.token = attrs['token']
      self.game_id = attrs['id'].to_i
      self.komi = attrs['komi'].to_f
      self.white_player_id = attrs['white_player_id'].to_i
      self.black_player_id = attrs['black_player_id'].to_i
      self.turn = attrs['turn']
      self.board_size = attrs['board']['size'].to_i
      self.move_number = attrs['move_number'].to_i
      self.handicap = attrs['handicap'].to_i rescue 0
      self.handicap_stones = attrs['handicap_stones']
      self.moves = []
      move_colors = ["B", "W"]
      handicap_offset = self.handicap > 0 ? 1 : 0
      if attrs['moves']
        attrs['moves'].each_with_index do |m,idx|
          self.moves << [move_colors[(idx+handicap_offset) % 2], sgf_coord_to_gtp_coord(m, board_size)]
        end
      end
      
      if state == 'new'
        GoshrineRequest.new("/game/#{token}/attempt_start").post
      end
      
    end
    
    def my_color
      @client.my_user_id == white_player_id ? "W" : "B"
    end
    
    def opponents_color
      @client.my_user_id == white_player_id ? "B" : "W"
    end
    
    def make_move
      return unless started? && my_turn?
      
      res = gtp_client.genmove(turn)
      res.callback { |response_move|
        puts "Generated move: #{response_move} (#{token})"
        self.move_number += 1
        request = nil
        if response_move.upcase == 'PASS'
          request = GoshrineRequest.new("/game/#{token}/pass").post
        elsif response_move.upcase == 'RESIGN'
          request = GoshrineRequest.new("/game/#{token}/resign").post
        else
          rgo_coord = gtp_coord_to_goshrine_coord(response_move.upcase, board_size)
          request = GoshrineRequest.new("/game/#{token}/move/#{rgo_coord}").post
        end
        request.callback { |http|
          if http.response_header.status == 200
            self.moves << [my_color, response_move]
          else
            puts "Could not make move: #{http.response}"
          end
        }
      }
    end
    
    def start_engine
      gtp = GtpStdioClient.new(@client.gtp_cmd_line, "gtp_#{token}.log")
      gtp.boardsize(@board_size)
      gtp.clear_board
      gtp.komi(@komi)
      
      if @handicap_stones.size > 0
        gtp_coords = @handicap_stones.map {|s| sgf_coord_to_gtp_coord(s, board_size) }
        gtp.set_free_handicap(gtp_coords.join(" "))
      end
      
      if @moves
        @moves.each do |m|
          #puts "Going to play #{m.first}, #{m.last}"
          gtp.play(m.first, m.last)
        end
      end
      gtp
    end
    
    def gtp_client
      @last_gtp_access = Time.now
      @gtp_client ||= start_engine
    end
    
    def stop_gtp_client
      @gtp_client.close if @gtp_client
      @gtp_client = nil
      @last_gtp_access = nil
    end
        
    def players_turn
      self.turn == 'b' ? black_player_id : white_player_id
    end
    
    def sgf_coord_to_gtp_coord(value, board_size)
      return 'pass' if value.downcase == 'pass'
      x = value[0].ord - 97
      y = value[1].ord - 97
      x += 1 if x >= 8
      [x+65].pack('c') + (board_size - y).to_s
    end
    
    def goshrine_coord_to_gtp_coord(value, board_size)
      x = value[0].ord - 97
      y = value[1].ord - 97
      x += 1 if x >= 8
      [x+65].pack('c') + (board_size - y).to_s
    end

    def gtp_coord_to_goshrine_coord(value, board_size)
      x = value[0].ord - 65
      x -= 1 if x >= 8
      y = board_size - (value[1..-1].to_i)
      [x+97, y+97].pack('cc')
    end
    
    
  end
end
