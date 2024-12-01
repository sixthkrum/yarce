#!/usr/bin/env ruby
# frozen_string_literal: true

require 'securerandom'
require_relative './device.rb'
require_relative './by2d_drawer.rb'

# 0xFFF - 0x200 + 1 is the total space
MAX_ROM_SIZE = 4095 - 512 + 1

if __FILE__ == $0
  load './src/main.rb'
  rom_file = "/home/sixthkrum/Downloads/roms/Chip8_emulator_Logo_Garstyciuks.ch8"
  rom_file = ARGV[0]

  if rom_file.nil?
    puts "Please pass a valid rom file as the first argument"
    exit(1)
  end

  unless File.exist?(rom_file)
    puts "File not found"
    exit(1)
  end

  rom = File.read(rom_file)

  bytes = rom.unpack("C*")

  # check if program will fit in memory
  unless bytes.size <= MAX_ROM_SIZE
    puts "Invalid rom, bigger than max size: #{MAX_ROM_SIZE} bytes"
  end

  device = Device.new

  bytes.each_with_index do |b, i|
    device.memory[512 + i] = b
  end
  device.program_counter = 512

  drawer = Drawers::Alpha.new

  while true
    current_high_byte = device.memory[device.program_counter]
    current_low_byte = device.memory[device.program_counter + 1]
    input_nibbles = [current_high_byte / 16, current_high_byte & 0b00001111,
                     current_low_byte / 16, current_low_byte & 0b00001111]

    device.execute_instruction(*input_nibbles)

    drawer.draw_pixel_array(32, 64, device.display)
  end
end
