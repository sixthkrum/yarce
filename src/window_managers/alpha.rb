# frozen_string_literal: true

require 'ruby2d/core'
require_relative './base'

module YARCE
  # window manager that uses Ruby2D
  module WindowManagers
    class Alpha < Base
      # TODO: make this configurable
      # input map:
      # 1 2 3 4 ||| 0 1 2 3
      # q w e r ||| 4 5 6 7
      # a s d f ||| 8 9 a b
      # z x c v ||| c d e f
      KEY_INPUT_MAP = {
        # for the keypad
        '1' => 0x0, '2' => 0x1, '3' => 0x2, '4' => 0x3,
        'q' => 0x4, 'w' => 0x5, 'e' => 0x6, 'r' => 0x7,
        'a' => 0x8, 's' => 0x9, 'd' => 0xa, 'f' => 0xb,
        'z' => 0xc, 'x' => 0xd, 'c' => 0xe, 'v' => 0xf,
        # special keys
        'space' => 0x10,
        'escape' => 0x11
      }

      KEY_EVENT_MAP = {
        :none => 0x0,
        :down => 0x1,
        :held => 0x2,
        :up => 0x3
      }

      def initialize(window_settings = {})
        @window_directive_handler = WindowDirectiveHandler.new(maxlen: 2048, packing_directive: 'C*')

        @window_process = Process.fork do
          @window_directive_handler.own(:child_socket)

          # the fps cap has been increased to increase the polling rate for the socket read
          # the rate at which newly prepared screens are shown to the user depends mostly on their production rate
          @window = Ruby2D::Window.new(title: window_settings[:title], fps_cap: 8192)

          @window.update do
            result = @window_directive_handler.read

            if result
              WindowManipulator.clear_screen(@window, [])
              # TODO pass the rest of the parameters through IPC as well
              WindowManipulator.draw_1d_bit_map(@window, 32, 64, @window_directive_handler.data, 10, :center)
            end
          end

          # TODO: handle every case of input handling
          #   this is possible with the current setup but is not worth implementing
          #   implementing a protocol for transferring data over sockets (per message decoding scheme, etc)
          #   will be better as it will allow us to handle more cases of this kind
          #   which could get reused in other projects down the line

          @window.on :key do |event|
            input = KEY_INPUT_MAP[event.key]

            unless input.nil?
              @window_directive_handler.write([KEY_EVENT_MAP[event.type], input])

              # stop the process if the escape key is pressed
              if input == 0x11
                @window.close

                exit(0)
              end
            end
          end

          @window.show

          # the control only comes here when the window has closed
          # send the main process the signal that the window has closed and that it needs to exit
          # by sending the escape key as a message
          @window_directive_handler.write([0x1, 0x11])
        end

        @window_directive_handler.own(:parent_socket)
      end

      # methods for setting the content of the window based on the drawing directive received
      class WindowManipulator
        def self.clear_screen(window, _)
          window.clear
        end

        def self.add_square(window, *args)
          window.add(Ruby2D::Square.new(color: args[0]))
        end

        # TODO: implement on color and off color for the pixels
        def self.draw_1d_bit_map(window, *args)
          height = args[0]
          width = args[1]
          bitmap = args[2]
          pixel_size = args[3]
          gravity = args[4]

          # gravity is northwest by default
          # TODO: implement all gravities
          case gravity
          when :center
            x_offset = (window.get(:width) - width * pixel_size) / 2
            y_offset = (window.get(:height) - height * pixel_size) / 2
          else
            x_offset = 0
            y_offset = 0
          end

          tileset = Ruby2D::Tileset.new("./src/window_managers/pixel.png", tile_width: 1, tile_height: 1, scale: pixel_size)
          tileset.define_tile('white', 0, 0)

          tiles = []
          height.times do |y|
            width.times do |x|
              if bitmap[(y * width) + x] != 0
                tiles << { x: (x * pixel_size) + x_offset, y: (y * pixel_size) + y_offset }
              end
            end
          end

          tileset.set_tile('white', tiles)

          window.add(tileset)
        end
      end
    end
  end
end