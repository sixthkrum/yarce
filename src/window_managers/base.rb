# frozen_string_literal: true

require 'socket'
require_relative '../helpers/connection'

module YARCE
  module WindowManagers
    class Base
      include Helpers::Connection

      attr_accessor :window_process
      attr_accessor :window_directive_handler

      # handles sending of window directives to the child process and sending back data to the parent process
      # unpacks the received string from the parent process into an array using the unpacking directive if desired
      # this should handle the parsing of the input for dynamic method calling etc. if needed
      WindowDirectiveHandler = Helpers::Connection::SocketConnectionHandler

      # class for translating drawing directives into actions on the screen, this will change per drawer implementation
      class WindowManipulator; end
    end
  end
end
