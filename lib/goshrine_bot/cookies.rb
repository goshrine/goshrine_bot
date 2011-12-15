# Borrowed from HTTParty, a great rubygem from John Nunemaker (thanks!)
class CookieHash < Hash #:nodoc:
  CLIENT_COOKIES = %w{path expires domain path secure HTTPOnly HttpOnly}
  
  def add_cookies(value)
    return if value.nil?
    case value
    when Hash
      merge!(value)
    when String
      value.split('; ').each do |cookie|
        array = cookie.split('=')
        self[array[0].to_sym] = array[1]
      end
    else
      raise "add_cookies only takes a Hash or a String"
    end
  end

  def to_cookie_string
    delete_if { |k, v| CLIENT_COOKIES.include?(k.to_s) }.collect { |k, v| "#{k}=#{v}" }.join("; ")
  end
end

class CookiePersist
  
  def cookies
    Thread.current[:cookies] ||= []
  end

  def cookie_hash
    CookieHash.new.tap { |hsh|
      cookies.uniq.each { |c| hsh.add_cookies(c) }
    }
  end

  def request(client, head, body)
    head['cookie'] = cookie_hash.to_cookie_string
    [head, body]
  end

  def response(resp)
    cookies << resp.response_header[EM::HttpClient::SET_COOKIE]
    resp
  end
end

