#!/usr/bin/env ruby
# frozen_string_literal: true

require 'securerandom'
require 'stackprof'
require_relative './device'
require_relative './window_managers/alpha'

# 0xFFF - 0x200 + 1 is the total space
MAX_ROM_SIZE = 4095 - 512 + 1

if __FILE__ == $0
  load './src/main.rb'
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

  device = YARCE::Device.new

  bytes.each_with_index do |b, i|
    device.memory[512 + i] = b
  end

  device.program_counter = 512
  last_program_counter_location = device.program_counter
  instruction_times = []

  drawer = YARCE::WindowManagers::Alpha.new({ title: 'Chip8' })

  clock_speed = (1.0 / 480.0)
  sixty_hertz_counter = 0
  StackProf.run(mode: :cpu, out: 'stackprof-output.dump') do
    while true do
      instruction_start_time = Time.now.to_f

      current_high_byte = device.memory[device.program_counter]
      current_low_byte = device.memory[device.program_counter + 1]

      break if current_high_byte.nil? || current_low_byte.nil?

      input_nibbles = [current_high_byte / 16, current_high_byte & 0b00001111,
                       current_low_byte / 16, current_low_byte & 0b00001111]

      device.execute_instruction(*input_nibbles)

      if last_program_counter_location == device.program_counter
        device.program_counter += 2
      end

      if device.last_instruction == :drw_vx_vy_n
        drawer.window_directive_handler.write(device.display)
      end

      last_program_counter_location = device.program_counter

      break if device.program_counter > 0xFFF

      sixty_hertz_counter += 1
      if sixty_hertz_counter == 8
        sixty_hertz_counter = 0
        device.decrement_delay_timer
        device.decrement_sound_timer
      end

      instruction_end_time = Time.now.to_f
      instruction_times << (instruction_end_time - instruction_start_time)

      sleep_time = (clock_speed - (instruction_end_time - instruction_start_time))
      sleep_time = 0 if sleep_time < 0

      sleep sleep_time
    end
  end
end
