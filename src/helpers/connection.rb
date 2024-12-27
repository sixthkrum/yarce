# frozen_string_literal: true

module YARCE
  module Helpers
    module Connection
      # sends strings to and fro between 2 processes using sockets
      # allows processes to own an end of the connection as required
      class SocketConnectionHandler
        attr_reader :data

        # maxlen is the maximum length to be read at a time, this length is
        def initialize(maxlen: 16384, packing_directive: '')
          @child_socket, @parent_socket = Socket.pair(:UNIX, :DGRAM, 0)
          @maxlen = maxlen

          raise 'maxlen must be a positive integer' unless maxlen.is_a?(Integer) && maxlen.positive?

          @packing_directive = packing_directive
        end

        def own(connection_end)
          raise 'Cannot own more than one connection end at once' unless @owned_connection_end.nil?

          case connection_end
          when :child_socket
            @parent_socket.close
            @owned_connection_end = @child_socket
          when :parent_socket
            @child_socket.close
            @owned_connection_end = @parent_socket
          else
            raise 'Must be either :child_socket or :parent_socket'
          end
        end

        # TODO: error handling
        def read
          raise 'Must own a connection end before reading' if @owned_connection_end.nil?

          result = @owned_connection_end.recv_nonblock(@maxlen, exception: false)

          unless result.nil? || result == :wait_readable
            @data = (@packing_directive.is_a?(String) && !@packing_directive.empty?) ? result.unpack(@packing_directive) : result

            return true
          end

          false
        end

        def write(data)
          raise 'Must own a connection end before writing' if @owned_connection_end.nil?

          @owned_connection_end.send(
            (@packing_directive.is_a?(String) && !@packing_directive.empty?) ? data.pack(@packing_directive) : data,
            0
          )
        end
      end
    end
  end
end
