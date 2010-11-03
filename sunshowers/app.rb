SINATRA_ROOT = File.expand_path(File.join(File.dirname(__FILE__))) unless defined?(SINATRA_ROOT)

# $KCODE='UTF8'
# require 'jcode'

require 'rubygems'
require "digest/md5"

begin
  gem 'json'
  require 'json/ext'
rescue LoadError
  gem 'json_pure'
  require 'json/pure'
end

require 'sunshowers'
require 'sinatra/base'

class Sinatra::Request < Rack::Request
  include Sunshowers::WebSocket
end

class Application < Sinatra::Base

  @@connections = {}
  @@uid = 0

  def connections
    @@connections
  end

  def uid
    @@uid += 1
  end

  def broadcast(msg, ws_io = nil)
    connections.each do |k, v|
      unless v == ws_io # This is the current connection
        v.write_utf8(msg)
      end
    end
  end

  def welcome(ws_io)
    ws_io.write_utf8("Welcome. Type `/nick USERNAME` to change your username.")
    ws_io.write_utf8("Connected users: '#{connections.keys.join("', '")}'.")
  end

  def help(ws_io)
    ws_io.write_utf8("Help:
      Type `/nick USERNAME` to change your username.
      Type `/quit` to exit.
    ")
  end

  configure do
    # Set this folder if using static files for html views
    set :public, File.join(SINATRA_ROOT, "public")
    set :static, :true
    use Rack::CommonLogger
  end

  get '/' do
    content_type :html
    erb :index
  end

  get "/chat" do
    begin
      # Connect:
      if request.ws?
        # Handsake:
        request.ws_handshake!
        ws_io = request.ws_io
        c_uid = uid
        connections[c_uid] = ws_io
        welcome(ws_io)
        # Broadcast:
        broadcast("User #{c_uid} connected.", ws_io)
        # Messages:
        ws_io.each do |record|
          if record == '/help'
            help(ws_io)
            next
          end

          if record =~ /^\/nick\s(.+)/
            new_nick = $1
            if connections.has_key?(new_nick)
              ws_io.write_utf8("Sorry, #{new_nick} is already in use. Try a different nick.")
              next
            else
              connections[new_nick] = ws_io
              ws_io.write_utf8("Successfully changed nick to '#{new_nick}'")
              broadcast("User '#{c_uid}' is now known as '#{new_nick}'", ws_io)
              connections.delete(c_uid)
              c_uid = new_nick
              next
            end
          end

          ws_io.write_utf8(record)
          # Broadcast:
          broadcast("User #{c_uid} says: #{record}", ws_io)
          break if record == "/quit"
        end
        # Close:
        connections.delete(c_uid)
        broadcast("User #{c_uid} disconnected", ws_io)
        request.ws_quit!
      end
    rescue Sunshowers::WebSocket::Quit => e
      $stderr.puts e.message
    end
    "You're not using Web Sockets"
  end
end


if __FILE__ == $0
  Application.run!
end
