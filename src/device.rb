# frozen_string_literal: true

# class for creating chip8 devices, this defines some of the parts of the device
class Device
  include BinaryHelpers

  attr_reader :display
  attr_accessor :key_pressed_this_frame

  def initialize(args = {})
    # holds the memory row wise with 64 bit row width
    @display = Array.new(2048, 0)
    @memory = Array.new(4096, 0)
    @registers_16 = Array.new(16, 0)
    @register_i = 0
    @sound_timer = 0
    @delay_timer = 0
    @program_counter = 0
    @stack_pointer = 0
    @stack = []
    @keypad_state = []
    @key_pressed_this_frame = nil
    @digit_location = []
  end

  # figure out which instruction to execute and execute it
  # instructions are sent as arrays containing 4 nibbles directly as binary numbers in big endian order

  def deduce_instruction(instruction)
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

  def execute_instruction(instruction)
    instruction_name = deduce_instruction(instruction)

    return if instruction_name.nil?

    send(instruction_name, instruction)
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
    @stack << @program_counter
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
    @program_counter += 2
  end

  def add_vx_b(instruction)
    @registers_16[instruction[1]] += instruction[2] * 16 + instruction[3]
    @registers_16[instruction[1]] &= 0b11111111
    @program_counter += 2
  end

  def ld_vx_vy(instruction)
    @registers_16[instruction[1]] = @registers_16[instruction[2]]
    @program_counter += 2
  end

  def or_vx_vy(instruction)
    @registers_16[instruction[1]] |= @registers_16[instruction[2]]
    @program_counter += 2
  end

  def and_vx_vy(instruction)
    @registers_16[instruction[1]] &= @registers_16[instruction[2]]
    @program_counter += 2
  end

  def xor_vx_vy(instruction)
    @registers_16[instruction[1]] ^= @registers_16[instruction[2]]
    @program_counter += 2
  end

  def add_vx_vy(instruction)
    @registers_16[instruction[1]] += @registers_16[instruction[2]]

    if @registers_16[instruction[1]] > 255
      @registers_16[instruction[1]] &= 0b11111111
      @registers_16[0xF] = 1
    else
      @registers_16[0xF] = 0
    end

    @program_counter += 2
  end

  def sub_vx_vy(instruction)
    @registers_16[instruction[1]] -= @registers_16[instruction[2]]

    if @registers_16[instruction[1]] < 0
      @registers_16[instruction[1]] = @registers_16[instruction[1]].abs ^ 0b11111111
      @registers_16[0xF] = 0
    else
      @registers_16[0xF] = 1
    end

    @program_counter += 2
  end

  def shr_vx(instruction)
    @registers_16[0xF] = ((@registers_16[instruction[1]] & 0b10000000) == 0b10000000)
    @registers_16[instruction[1]] /= 2

    @program_counter += 2
  end

  def subn_vx_vy(instruction)
    @registers_16[instruction[1]] = @registers_16[instruction[2]] - @registers_16[instruction[1]]

    if @registers_16[instruction[1]] < 0
      @registers_16[instruction[1]] = @registers_16[instruction[1]].abs ^ 0b11111111
      @registers_16[0xF] = 0
    else
      @registers_16[0xF] = 1
    end

    @program_counter += 2
  end

  def shl_vx(instruction)
    @registers_16[0xF] = ((@registers_16[instruction[1]] & 0b10000000) == 0b10000000)
    @registers_16[instruction[1]] *= 2
    @registers_16[instruction[1]] &= 0b11111111

    @program_counter += 2
  end

  def ld_i_a(instruction)
    @register_i = instruction[1] * 256 + instruction[2] * 16 + instruction[3]

    @program_counter += 2
  end

  def jp_v0_a(instruction)
    @program_counter = (instruction[1] * 256 + instruction[2] * 16 + instruction[3] + @registers_16[0]) & 0xFFFF
  end

  def rnd_vx_b(instruction)
    @registers_16[instruction[1]] = SecureRandom.bytes(1).unpack('C').first & (instruction[2] * 16 + instruction[3])

    @program_counter += 2
  end

  def drw_vx_vy_n(instruction)
    sprite = @memory[@register_i..(@register_i + instruction[3])]

    xor_bits = sprite.map { |e| number_to_binary_array(e, 8) }.flatten

    display_index = @registers_16[instruction[1]] + @registers_16[instruction[2]] * 64
    xor_bits.each_with_index do |bit, i|
      @display[(display_index + i) % 64] ^= bit
    end

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
    while true
      pressed_key = @key_pressed_this_frame

      break unless pressed_key.nil?
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
    @register_i &= 0xFFFF

    @program_counter += 2
  end

  def ld_f_vx(instruction)
    @register_i = @digit_location[@registers_16[instruction[1]]]

    @program_counter += 2
  end

  def ld_b_vx(instruction)
    bcd_array = number_to_bcd(@registers_16[instruction[1]])

    3.times do |i|
      @memory[@registers_i + i] = bcd_array[i]
    end

    @program_counter += 2
  end

  def ld_i_vx(instruction)
    (instruction[1] + 1).times do |i|
      @memory[@registers_i + i] = @registers_16[i]
    end

    @program_counter += 2
  end

  def ld_vx_i(instruction)
    (instruction[1] + 1).times do |i|
      @registers_16[i] = @memory[@registers_i + i]
    end

    @program_counter += 2
  end
end
