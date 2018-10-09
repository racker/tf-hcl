module Tf
  module Hcl
    class Lexer < RLTK::Lexer
      rule(/\s/)
      rule(/{/) { :LBRACE }
      rule(/}/) { :RBRACE }
      rule(/\[/) { :LBRACKET }
      rule(/]/) { :RBRACKET }
      rule(/,/) { :COMMA }
      rule(/:/) { :COLON }
      # Keywords
      rule(/variable/) { :VARIABLE }
      rule(/module/) { :MODULE }
      rule(/resource/) { :RESOURCE }
      rule(/output/) { :OUTPUT }
      rule(/locals/) { :LOCALS }
      rule(/provider/) { :PROVIDER }
      rule(/data/) { :DATA }
      rule(/terraform/) { :TERRAFORM }
      rule(/atlas/) { :ATLAS }
      rule(/=/) { :ASSIGN }
      # Booleans
      rule(/true|false/) { |t| [:BOOLEAN, t == 'true' ? true : false] }
      # Strings: Ignore any double quotes inside interpolation ${} (can be nested), also ignore escaped double quotes i.e. \"
      rule(/"/) { push_state :string }
      # TODO: can't figure out how to capture the outer '${}' in this regex...hmph
      # rule(/(?={((?:[^{}]++|{\g<1>})++)})/m, :string) { |t| append("${#{match[1]}}") }
      rule(/\${/m, :string) { |t| incr_counter; set_flag(:variable); append(t) }
      rule(/[^}]/, :string, [:variable]) { |t| append(t) }
      rule(/}/, :string, [:variable]) { |t| decr_counter; unset_flag(:variable) if counter == 0; append(t) }
      rule(/[^"]/m, :string) { |t| append(t) }
      rule(/\\"/, :string) { |t| append(t) }
      rule(/"/, :string) { |t| pop_state; [:STRING, reset] }
      # Floats
      rule(/\d*?\.\d+/) { |t| [:FLOAT, t.to_f] }
      # Octal
      rule(/0\d+/) { |t| [:OCTAL, t.to_i(8)] }
      # Integers
      rule(/[0-9]\d*/) { |t| [:INTEGER, t.to_i] }
      # -ve Integers for Step Adjustment in ASG
      rule(/-[1-9]\d*/) { |t| [:INTEGER, t.to_i] }
      # Hexadecimal
      rule(/0x[A-Fa-f\d]+/) { |t| [:HEXADECIMAL, t.to_i(16)] }
      # Scientific Notation
      rule(/\d*?\.?\d+[eE]\d+/) { |t| [:SCIENTIFIC_NOTATION, ::BigDecimal.new(t)] }
      # Identifiers
      rule(/[A-Za-z][A-Za-z0-9\-\_.]*/) { |t| [:IDENT, t] }
      # Single line comments
      rule(/#/) { |t| push_state :comment }
      rule(/.*/, :comment) { |t| [:COMMENT, t] }
      rule(/\n/, :comment) { pop_state }
      # Multiline comments
      rule(/\/\*(.*?)\*\//m) { |t| [:MULTILINE_COMMENT, match[1]] }
      # Multiline strings
      rule(/<<([A-Za-z0-9]+)(.*?)\1/m) { |t| [:MULTILINE_STRING, [match[2], match[1]]] }

      class Environment < Environment

        def incr_counter
          @counter = 0 if @counter.nil?
          @counter += 1
        end

        def decr_counter
          @counter -= 1
        end

        def reset_counter
          @counter = nil
        end

        def counter
          @counter
        end

        def append(c)
          @str = '' if @str.nil?
          @str += c
          nil
        end

        def reset
          str_copy = @str.dup
          @str = ''
          str_copy
        end
      end
    end
  end
end
