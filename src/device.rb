# frozen_string_literal: true

# class for creating chip8 devices, this defines some of the parts of the device

require_relative './helpers/binary'

module YARCE
  class Device
    include Helpers::Binary

    attr_accessor :display
    attr_accessor :key_pressed_this_frame
    attr_accessor :memory
    attr_accessor :program_counter
    attr_reader :last_instruction
    attr_accessor :keypad_state
    attr_accessor :seconds_per_instruction
    attr_reader :sound_timer

    def initialize(args = {})
      # holds the memory row wise with 64 pixel row width and 32 pixel column height
      @display = Array.new(2048, 0)
      @memory = Array.new(4096, 0)
      @registers_16 = Array.new(16, 0)
      @register_i = 0
      @sound_timer = 0
      @delay_timer = 0
      @program_counter = 0
      @stack_pointer = 0
      @stack = []
      @keypad_state = Array.new(16, false)
      @key_pressed_this_frame = nil
      @last_instruction = nil
      @seconds_per_instruction = args[:seconds_per_instruction]

      unless @seconds_per_instruction.is_a?(Numeric) && @seconds_per_instruction > 0
        raise 'the :seconds_per_instruction must be passed and be a positive number'
      end

      [
        0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
        0x20, 0x60, 0x20, 0x20, 0x70, # 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
        0x90, 0x90, 0xF0, 0x10, 0x10, # 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
        0xF0, 0x10, 0x20, 0x40, 0x40, # 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, # A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
        0xF0, 0x80, 0x80, 0x80, 0xF0, # C
        0xE0, 0x90, 0x90, 0x90, 0xE0, # D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
        0xF0, 0x80, 0xF0, 0x80, 0x80, # F
      ].each_with_index do |b, i|
        @memory[i] = b
      end

      # map digit bit maps to their starting location in memory for ld_f_vx
      @digit_location = {
        0 => 0,
        1 => 5,
        2 => 10,
        3 => 15,
        4 => 20,
        5 => 25,
        6 => 30,
        7 => 35,
        8 => 40,
        9 => 45,
        0xA => 50,
        0xB => 55,
        0xC => 60,
        0xD => 65,
        0xE => 70,
        0xF => 75
      }
    end

    def dump_state
      Marshal.dump(self)
    end

    def load_state(data)
      loaded_object = Marshal.load(data)

      self.instance_variables.each do |e|
        self.instance_variable_set(e, loaded_object.instance_variable_get(e))
      end
    end

    # figure out which instruction to execute and execute it
    # instructions are sent as arrays containing 4 nibbles directly as binary numbers in big endian order

    def deduce_instruction(*instruction)
      case instruction[0]
      when 0
        case instruction[1]
        when 0
          case instruction[2]
          when 0xE
            case instruction[3]
            when 0
              :cls
            when 0xE
              :ret
            else
              # ignored
            end
          else
            # ignored
          end
        else
          # ignored
        end
      when 1
        :jp_a
      when 2
        :call_a
      when 3
        :se_vx_b
      when 4
        :sne_vx_b
      when 5
        :se_vx_vy
      when 6
        :ld_vx_b
      when 7
        :add_vx_b
      when 8
        case instruction[3]
        when 0
          :ld_vx_vy
        when 1
          :or_vx_vy
        when 2
          :and_vx_vy
        when 3
          :xor_vx_vy
        when 4
          :add_vx_vy
        when 5
          :sub_vx_vy
        when 6
          :shr_vx
        when 7
          :subn_vx_vy
        when 0xE
          :shl_vx
        else
          # ignored
        end
      when 9
        :sne_vx_vy
      when 0xA
        :ld_i_a
      when 0xB
        :jp_v0_a
      when 0xC
        :rnd_vx_b
      when 0xD
        :drw_vx_vy_n
      when 0xE
        case instruction[2]
        when 9
          :skp_vx
        when 0xA
          :sknp_vx
        else
          # ignored
        end
      when 0xF
        case instruction[2]
        when 0
          case instruction[3]
          when 7
            :ld_vx_dt
          when 0xA
            :ld_vx_k
          else
            # ignored
          end
        when 1
          case instruction[3]
          when 5
            :ld_dt_vx
          when 8
            :ld_st_vx
          when 0xE
            :add_i_vx
          else
            # ignored
          end
        when 2
          :ld_f_vx
        when 3
          :ld_b_vx
        when 5
          :ld_i_vx
        when 6
          :ld_vx_i
        else
          # ignored
        end
      else
        # ignored
      end
    end

    def execute_instruction(*instruction)
      instruction_name = deduce_instruction(*instruction)

      @last_instruction = instruction_name

      return if instruction_name.nil?

      send(instruction_name, instruction)
    end

    def decrement_sound_timer
      @sound_timer -= 1 if @sound_timer > 0
    end

    def decrement_delay_timer
      @delay_timer -= 1 if @delay_timer > 0
    end

    private

    def cls(_)
      @display.map! { 0 }
      @program_counter += 2
    end

    def ret(_)
      @program_counter = @stack.pop
    end

    def jp_a(instruction)
      @program_counter = instruction[1] * 256 + instruction[2] * 16 + instruction[3]
    end

    def call_a(instruction)
      # return to the instruction after this one
      @stack << (@program_counter + 2)
      @program_counter = instruction[1] * 256 + instruction[2] * 16 + instruction[3]
    end

    def se_vx_b(instruction)
      if @registers_16[instruction[1]] == instruction[2] * 16 + instruction[3]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def sne_vx_b(instruction)
      if @registers_16[instruction[1]] != instruction[2] * 16 + instruction[3]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def se_vx_vy(instruction)
      if @registers_16[instruction[1]] == @registers_16[instruction[2]]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def sne_vx_vy(instruction)
      if @registers_16[instruction[1]] != @registers_16[instruction[2]]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def ld_vx_b(instruction)
      @registers_16[instruction[1]] = instruction[2] * 16 + instruction[3]
      @registers_16[instruction[1]] %= 0x100

      @program_counter += 2
    end

    def add_vx_b(instruction)
      @registers_16[instruction[1]] += instruction[2] * 16 + instruction[3]
      @registers_16[instruction[1]] %= 0x100

      @program_counter += 2
    end

    def ld_vx_vy(instruction)
      @registers_16[instruction[1]] = @registers_16[instruction[2]]
      @program_counter += 2
    end

    def or_vx_vy(instruction)
      @registers_16[instruction[1]] |= @registers_16[instruction[2]]
      @registers_16[0xF] = 0
      @program_counter += 2
    end

    def and_vx_vy(instruction)
      @registers_16[instruction[1]] &= @registers_16[instruction[2]]
      @registers_16[0xF] = 0
      @program_counter += 2
    end

    def xor_vx_vy(instruction)
      @registers_16[instruction[1]] ^= @registers_16[instruction[2]]
      @registers_16[0xF] = 0
      @program_counter += 2
    end

    def add_vx_vy(instruction)
      @registers_16[instruction[1]] += @registers_16[instruction[2]]

      if @registers_16[instruction[1]] > 0xFF
        @registers_16[instruction[1]] %= 0x100
        @registers_16[0xF] = 1
      else
        @registers_16[0xF] = 0
      end

      @program_counter += 2
    end

    def sub_vx_vy(instruction)
      @registers_16[instruction[1]] -= @registers_16[instruction[2]]

      if @registers_16[instruction[1]] < 0
        @registers_16[instruction[1]] += 256
        @registers_16[0xF] = 0
      else
        @registers_16[0xF] = 1
      end

      @program_counter += 2
    end

    def shr_vx(instruction)
      flag = (@registers_16[instruction[2]] & 1)

      @registers_16[instruction[1]] = (@registers_16[instruction[2]] >> 1)
      @registers_16[instruction[1]] &= 0xFF

      @registers_16[0xF] = flag

      @program_counter += 2
    end

    def subn_vx_vy(instruction)
      @registers_16[instruction[1]] = @registers_16[instruction[2]] - @registers_16[instruction[1]]

      if @registers_16[instruction[1]] < 0
        @registers_16[instruction[1]] += 256
        @registers_16[0xF] = 0
      else
        @registers_16[0xF] = 1
      end

      @program_counter += 2
    end

    def shl_vx(instruction)
      flag = ((@registers_16[instruction[2]] & 0b10000000) == 0b10000000 ? 1 : 0)

      @registers_16[instruction[1]] = (@registers_16[instruction[2]] << 1)
      @registers_16[instruction[1]] &= 0xFF

      @registers_16[0xF] = flag

      @program_counter += 2
    end

    def ld_i_a(instruction)
      @register_i = instruction[1] * 256 + instruction[2] * 16 + instruction[3]

      @program_counter += 2
    end

    def jp_v0_a(instruction)
      @program_counter = ((instruction[1] * 256 + instruction[2] * 16 + instruction[3] + @registers_16[0]) % 0x10000)
    end

    def rnd_vx_b(instruction)
      @registers_16[instruction[1]] = SecureRandom.bytes(1).unpack('C').first & (instruction[2] * 16 + instruction[3])

      @program_counter += 2
    end

    # TODO make the display size configurable
    def drw_vx_vy_n(instruction)
      sprite = @memory[@register_i..((@register_i + instruction[3]) - 1)]

      xor_bit_sets = sprite[0..(instruction[3] - 1)].map { |e| number_to_binary_array(e, 8) }

      collision_status = 0
      starting_y = @registers_16[instruction[2]] % 32
      starting_x = @registers_16[instruction[1]] % 64
      xor_bit_sets.each_with_index do |bitset, i|
        display_row_start = (starting_y + i) * 64

        next if display_row_start >= 2048

        bitset.each_with_index do |bit, j|
          x_offset = starting_x + j

          break if x_offset >= 64

          pixel_index = display_row_start + x_offset

          collision_check = @display[pixel_index]
          @display[pixel_index] ^= bit

          collision_status |= collision_check & (~@display[pixel_index])
        end
      end

      @registers_16[0xF] = collision_status

      @program_counter += 2
    end

    def skp_vx(instruction)
      if @keypad_state[@registers_16[instruction[1]]]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def sknp_vx(instruction)
      unless @keypad_state[@registers_16[instruction[1]]]
        @program_counter += 2
      end

      @program_counter += 2
    end

    def ld_vx_dt(instruction)
      @registers_16[instruction[1]] = @delay_timer

      @program_counter += 2
    end

    def ld_vx_k(instruction)
      pressed_key = nil
      while true do
        pressed_key = @key_pressed_this_frame

        break unless pressed_key.nil?

        sleep @seconds_per_instruction
      end

      while @keypad_state[pressed_key]
        sleep @seconds_per_instruction
      end

      @registers_16[instruction[1]] = pressed_key

      @program_counter += 2
    end

    def ld_dt_vx(instruction)
      @delay_timer = @registers_16[instruction[1]]

      @program_counter += 2
    end

    def ld_st_vx(instruction)
      @sound_timer = @registers_16[instruction[1]]

      @program_counter += 2
    end

    def add_i_vx(instruction)
      @register_i += @registers_16[instruction[1]]
      @register_i %= 0x10000

      @program_counter += 2
    end

    def ld_f_vx(instruction)
      @register_i = @digit_location[@registers_16[instruction[1]]]

      @program_counter += 2
    end

    def ld_b_vx(instruction)
      bcd_array = number_to_bcd(@registers_16[instruction[1]], 3)

      3.times do |i|
        @memory[@register_i + i] = bcd_array[i]
      end

      @program_counter += 2
    end

    def ld_i_vx(instruction)
      (instruction[1] + 1).times do |i|
        @memory[@register_i + i] = @registers_16[i]
      end

      @register_i += instruction[1] + 1
      @register_i %= 0x10000

      @program_counter += 2
    end

    def ld_vx_i(instruction)
      (instruction[1] + 1).times do |i|
        @registers_16[i] = @memory[@register_i + i]
      end

      @register_i += instruction[1] + 1
      @register_i %= 0x10000

      @program_counter += 2
    end
  end
end
