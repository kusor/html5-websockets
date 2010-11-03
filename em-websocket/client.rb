$LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '..', "web-socket-ruby/lib"))

if ARGV.size < 1
  $stderr.puts("Usage: ruby #{$0} ws://HOST:PORT/")
  exit(1)
end

require "rubygems"
require "web_socket"

begin
  gem 'json'
  require 'json/ext'
rescue LoadError
  gem 'json_pure'
  require 'json/pure'
end

WebSocket.debug = true if $DEBUG
Thread.abort_on_exception = true

if ARGV.size == 2 && ARGV[1] == "75"
  client = WebSocket.new(ARGV[0], {:seventy_five => true})
else
  client = WebSocket.new(ARGV[0])
end

puts("Connected")


Thread.new() do
  while data = client.receive()
    begin
      out = JSON.parse(data)
      out.each do |k, v|
        case k
        when 'info'
          if v.kind_of?(Array)
            v.each {|i| printf("-- INFO: %s --\n", i)}
          else
            printf("-- INFO: %s --\n", v)
          end

        when 'stats'
          printf("-- STATS: RSS=%sMB, UPTIME=%s -- \n", v['rss'], v['uptime'])
        else
          printf("%s\n", v)
        end
      end
    rescue JSON::ParserError => e
      printf("Error parsing JSON: %p\n", e.message)
    end
  end
end




begin
  $stdin.each_line() do |line|
    data = line.chomp()
    client.send(data)
    printf("Sent: %p\n", data)
  end
rescue Exception => e
  stats = `ps -o rss= -o etime= -p #{Process.pid}`.strip.split
  printf("\n--Client stats: RSS=%sMB, UPTIME=%s\n", (stats[0].to_i/1024), stats[1])
  client.close()
  exit
end




