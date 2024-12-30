#!/usr/bin/env ruby
# frozen_string_literal: true

require 'securerandom'
require 'stackprof'
require_relative './device'
require_relative './window_managers/alpha'

# 0xFFF - 0x200 + 1 is the total space
MAX_ROM_SIZE = 4095 - 512 + 1

return unless __FILE__ == $0

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

clock_speed = 480
seconds_per_instruction = 1.0 / clock_speed
# count the number of cycles and decrement the sound and delay registers when the
# (number of cycles passed) * (time per cycle) equals (1 / 60) seconds
# which is equivalent to sixty_hertz_counter equaling sixty_hertz_counter_check_value
sixty_hertz_counter = 0
sixty_hertz_counter_check_value = (clock_speed / 60.0).ceil

device = YARCE::Device.new(seconds_per_instruction: seconds_per_instruction)

bytes.each_with_index do |b, i|
  device.memory[512 + i] = b
end

device.program_counter = 512
instruction_times = []
sleep_times = []

window_manager = YARCE::WindowManagers::Alpha.new({ title: 'Chip8' })

# TODO: implement changing the sixty_hertz_counter_check_value based on some integer pattern like 8, 8, 9 to handle
#   non integer values like 8.3333
StackProf.run(mode: :cpu, out: 'stackprof-output.dump') do
  Thread.abort_on_exception = true

  # making another thread for input handling to make the blocking aspect reside in the device implementation and not
  # the implementation that calls the device
  # TODO: look into making all the concurrent stuff into fibers
  Thread.new do
    while true do
      result = window_manager.window_directive_handler.read

      if result
        input_data = window_manager.window_directive_handler.data

        case input_data[0]
        when 1 # key down code
          if input_data[1] < 0x10
            device.key_pressed_this_frame = input_data[1]
            device.keypad_state[device.key_pressed_this_frame] = true
          else
            case input_data[1]
            when 0x10 # space
              # open debugging menu
            when 0x11 # escape
              # exit
              exit(0)
            else
              nil
            end
          end
        when 3 # key up code
          device.keypad_state[input_data[1]] = false
        else
          nil
        end
      end

      sleep seconds_per_instruction / 2
    end
  end

  while true do
    instruction_start_time = Time.now.to_f

    current_high_byte = device.memory[device.program_counter]
    current_low_byte = device.memory[device.program_counter + 1]

    break if current_high_byte.nil? || current_low_byte.nil?

    input_nibbles = [current_high_byte / 16, current_high_byte & 0b00001111,
                     current_low_byte / 16, current_low_byte & 0b00001111]

    device.execute_instruction(*input_nibbles)

    if device.last_instruction == :drw_vx_vy_n
      window_manager.window_directive_handler.write(device.display)
    end

    # program counter being nil handles the return case wherein the stack is empty
    break if (device.program_counter.nil? || device.program_counter > 0xFFF)

    sixty_hertz_counter += 1
    if sixty_hertz_counter == sixty_hertz_counter_check_value
      sixty_hertz_counter = 0
      device.decrement_delay_timer
      device.decrement_sound_timer
    end

    instruction_end_time = Time.now.to_f
    instruction_time = (instruction_end_time - instruction_start_time)
    instruction_times << instruction_time

    sleep_time = (seconds_per_instruction - instruction_time)
    sleep_times << sleep_time
    sleep_time = 0 if sleep_time < 0

    # reset the key pressed this frame to prevent buffered input scenarios
    device.key_pressed_this_frame = nil

    sleep sleep_time
  end

  while true do
    sleep seconds_per_instruction
  end
end
