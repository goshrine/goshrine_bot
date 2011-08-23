class FayeAuthExt
  def initialize(user_id, token)
    @user_id = user_id
    @token = token
  end
  
  def outgoing(message, callback)
    # Add ext field if it's not present
    message['ext'] ||= {}

    # Set the auth token
    message['ext']['authToken'] = "#{@user_id}:#{@token}"

    # Carry on and send the message to the server
    callback.call(message)
  end
end
