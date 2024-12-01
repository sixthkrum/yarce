# has helper functions for working with numbers in a binary format

module BinaryHelpers
  # return lsb_count least significant bits of a number
  def number_to_binary_array(number, lsb_count)
    return [] unless bit_size > 0

    number = number.to_i.abs
    subtractor = 2 ** (lsb_count - 1)

    if number > subtractor
      ((number.to_f / subtractor.to_f) / 2.0).floor.times do
        subtractor *= 2
      end
    end

    bit_array = []

    while subtractor >= 1
      if number >= subtractor
        number -= subtractor
        bit_array << 1
      else
        bit_array << 0
      end

      subtractor /= 2
      puts bit_array
      puts subtractor
    end

    bit_array[-lsb_count..-1]
  end


  # convert a number to its bcd representation
  def number_to_bcd(number)
    digit_array = []

    number = number.to_i.abs
    modulus_value = 10
    while number > 0
      remainder = number % modulus_value
      digit_array << remainder / (modulus_value / 10)
      number -= remainder
      modulus_value *= 10
    end

    digit_array.reverse
  end
end
