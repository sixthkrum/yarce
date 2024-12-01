# frozen_string_literal: true

require 'ruby2d/core'

# drawer that uses Ruby2D to draw things onto the screen
module Drawers
  class Alpha
    attr_accessor :drawing_process
    attr_accessor :drawing_directive
    def initialize
      @drawing_directive = {}
      Process.fork do
        @window = Ruby2D::Window.new
        a = Ruby2D::Square.new
        @window.add(a)
        tick = 0
        @window.update do
          tick += 1
          if tick % 60 == 0
            @window.set(background: 'random')
            a = Ruby2D::Square.new(color: @drawing_directive[:color] || 'random')
            @window.add(a)
          end
        end
        @window.show
      end
    end
  end
end
