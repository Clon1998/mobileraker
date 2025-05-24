/*
 * Copyright (c) 2025. Patrick Schmidt.
 * All rights reserved.
 */

class Superscript {
  // Superscript numbers
  static const String zero = '⁰'; // U+2070
  static const String one = '¹'; // U+00B9
  static const String two = '²'; // U+00B2
  static const String three = '³'; // U+00B3
  static const String four = '⁴'; // U+2074
  static const String five = '⁵'; // U+2075
  static const String six = '⁶'; // U+2076
  static const String seven = '⁷'; // U+2077
  static const String eight = '⁸'; // U+2078
  static const String nine = '⁹'; // U+2079

  // Superscript operators
  static const String plus = '⁺'; // U+207A
  static const String minus = '⁻'; // U+207B
  static const String equals = '⁼'; // U+207C

  // Helper method to convert regular numbers to superscript
  static String fromNumber(int number) {
    const digits = [zero, one, two, three, four, five, six, seven, eight, nine];
    return number.toString().split('').map((char) {
      final digit = int.tryParse(char);
      return digit != null ? digits[digit] : char;
    }).join();
  }
}
