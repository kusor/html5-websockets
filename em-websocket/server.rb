SINATRA_ROOT = File.expand_path(File.join(File.dirname(__FILE__))) unless defined?(SINATRA_ROOT)
require "digest/md5"
require 'erb'
require 'rubygems'

require 'em-websocket'
require 'sinatra/base'

require 'thin'

begin
  gem 'json'
  require 'json/ext'
rescue LoadError
  gem 'json_pure'
  require 'json/pure'
end

if RUBY_VERSION == '1.9.2'
  app_port = 8001
  ws_port = 8081
else
  app_port = 8002
  ws_port = 8082
end

class Application < Sinatra::Base

  configure do
    set :app_file, __FILE__
    set :public, File.join(SINATRA_ROOT, "public")
    set :static, :true
    use Rack::CommonLogger
  end

  get '/' do
    File.read(File.join(settings.public, 'index.html'))
  end

end

class ChatChannel < EventMachine::Channel
  def count
    @subs.size
  end

  def subscribers
    @subs
  end
  # Send a message to the channel. If sid is specified,
  # do not send that message to the subscriber owning it.
  def broadcast(msg, sid = nil)
    @subs.each do |k, v|
      EM.schedule { v.call(msg) } unless k == sid
    end
  end

  def subscribe_with_nick(nick, *a, &b)
    EM.schedule { @subs[nick] = EM::Callback(*a, &b) }
    nick
  end

end

def welcome(ws)
  ws.send({'info' => "Welcome. Type '/help' for more information."}.to_json)
end

def help(ws)
  ws.send({'info' => [
    "Type '/nick USERNAME' to change your username.",
    # Don't think I'll implement this?. Maybe for command line only?.
    "Type '/quit' to exit."
  ]}.to_json)
end

EventMachine.run do

  @channel = ChatChannel.new

  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => ws_port, :debug => true) do |ws|
  # EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|

      ws.onopen {
        sid = @channel.subscribe { |msg| ws.send msg }
        # $stdout.puts @channel.methods.sort.inspect
        @channel.broadcast({'info' => "User '#{sid}' connected!"}.to_json, sid)
        @channel.push({'roaster' => @channel.subscribers.keys}.to_json)
        welcome(ws)
        ws.send({'info' => "Connected users: '#{@channel.subscribers.keys.join("', '")}'."}.to_json)

        ws.onmessage { |msg|
          case msg
          when '/help'
            help(ws)
          when /^\/nick\s(.+)/
            new_nick = $1
            if @channel.subscribers.has_key?(new_nick)
              ws.send({'info' => "Sorry, #{new_nick} is already in use. Try with a different one."}.to_json)
            else
              old_sid = sid
              @channel.unsubscribe(old_sid)
              sid = @channel.subscribe_with_nick(new_nick) { |msg| ws.send msg }
              ws.send({'info' => "Successfully changed nick to '#{new_nick}'"}.to_json)
              @channel.broadcast({'info' => "User '#{old_sid}' is now known as '#{new_nick}'"}.to_json, sid)
              @channel.push({'roaster' => @channel.subscribers.keys}.to_json)
            end
          else
            @channel.push({'message' => "<#{sid}>: #{msg}" }.to_json)
          end
        }

        ws.onclose   {
          @channel.unsubscribe(sid)
          @channel.push({'info' => "User '#{sid}' left the channel."}.to_json)
          ws.send({'info' => "WebSocket closed"}.to_json)
          @channel.push({'roaster' => @channel.subscribers.keys}.to_json)
        }

      }

      ws.onerror { |err|
        $stdout.puts "Error: #{err.inspect}"
      }

  end

  EventMachine::add_periodic_timer(30) {
    stats = `ps -o rss= -o etime= -p #{Process.pid}`.strip.split
    @channel.push({'stats' => {
      'rss' => (stats[0].to_i/1024),
      'uptime' => stats[1]
    }}.to_json) if stats.length == 2
  }

  Application.run!(:port => app_port)

end
