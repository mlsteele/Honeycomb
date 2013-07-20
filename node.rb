require 'socket'

class Node

  # start the Node server
  #
  # ==== Attributes
  #
  # * +comm_port+ - Port used to communicate with other nodes.
  # * +user_port+ - Port used for user requests
  def boot comm_port, user_port
    puts "booting Node"
    puts "comm_port: #{comm_port}"
    puts "user_port: #{user_port}"

    @server = TCPServer.new comm_port
    loop do
      client = @server.accept
      client.puts "Hello !"
      client.puts "Time is #{Time.now}"
      client.close
    end
  end
end


n = Node.new

server_type = ARGV[0]
puts "server: #{server_type}"
if server_type == "a"
  n.boot 8940, 8941
elsif server_type == "b"
  n.boot 8940, 8941
else
  puts "unrecognized server type"
end
