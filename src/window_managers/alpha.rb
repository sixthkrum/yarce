# frozen_string_literal: true

require 'ruby2d/core'
require_relative './base'

module YARCE
  # window manager that uses Ruby2D
  module WindowManagers
    class Alpha < Base
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
              # TODO pass the rest of the parameters through IPC as well
              WindowManipulator.draw_1d_bit_map(@window, 32, 64, @window_directive_handler.data, 10, :center)
            end
          end


          @window.on :key do |event|
            puts event
          end

          @window.show
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