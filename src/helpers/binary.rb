# frozen_string_literal: true

module YARCE
  module Helpers
    module Binary
      # return lsb_count least significant bits of a number
      def number_to_binary_array(number, lsb_count)
        return [] unless lsb_count > 0

        number = number.to_i.abs
        subtracting_number = 2 ** (lsb_count - 1)

        if number > subtracting_number
          ((number.to_f / subtracting_number.to_f) / 2.0).floor.times do
            subtracting_from *= 2
          end
        end

        bit_array = []

        while subtracting_number >= 1
          if number >= subtracting_number
            number -= subtracting_number
            bit_array << 1
          else
            bit_array << 0
          end

          subtracting_number /= 2
        end

        bit_array[-lsb_count..-1]
      end

      # convert a number to its bcd representation
      def number_to_bcd(number, digit_count)
        digit_array = []

        number = number.to_i.abs
        modulus_value = 10
        number_of_digits = 0
        while number > 0
          remainder = number % modulus_value
          digit_array << remainder / (modulus_value / 10)
          number -= remainder
          modulus_value *= 10
          number_of_digits += 1
        end

        unless digit_count.nil? || number_of_digits == digit_count
          if number_of_digits > digit_count
            digit_array = digit_array[0..(digit_count - 1)] || []
          else
            (digit_count - number_of_digits).times do
              digit_array.append(0)
            end
          end
        end

        digit_array.reverse
      end
    end
  end
end