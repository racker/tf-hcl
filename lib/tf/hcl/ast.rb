require 'rltk/ast'

module Tf
  module Hcl
    INDENT_SPACES = 2
    class BaseNode < RLTK::ASTNode
      def value
        values.first
      end

      # lines arg can either be:
      # :all - indent all lines
      # Integer - indent the first int number of lines, leave the rest as is
      def indent(hcl, level = 0, lines = :all)
        indent_spaces = ' ' * level * INDENT_SPACES
        parts = hcl.split("\n")
        indented_parts =
          if lines == :all
            parts.map { |l| indent_spaces + l }
          elsif lines.is_a?(::Integer)
            (parts.take(lines).map { |l| indent_spaces + l } + parts.drop(lines))
          else
            parts
          end
        indented_parts.join("\n")
      end
    end

    class Comment < BaseNode
      value :value, ::String

      def to_hcl
        "##{value}"
      end
    end

    class MultiLineComment < Comment
      def to_hcl
        "/* #{value.split("\n").map(&:strip).join("\n   ").sub(/[[:blank:]]*\Z/, '')}*/"
      end
    end

    class Key < BaseNode
      value :name, ::String

      def to_hcl
        if value[/[A-Za-z_]+/] == value
          value
        else
          "\"#{value}\""
        end
      end
    end

    class Value < BaseNode
      def to_hcl(level = 0)
        value
      end
    end

    class MultiLineString < Value
      value :value, ::String
      value :identifier, ::String

      def to_hcl(level = 0)
        "<<#{identifier}#{value}#{identifier}"
      end
    end

    class Integer < Value
      value :value, ::Integer
    end

    class Float < Value
      value :value, ::Float
    end

    class Hexadecimal < Integer
      def to_hcl(level = 0)
        '0x%X' % value
      end
    end

    class Octal < Integer
      def to_hcl(level = 0)
        '0%o' % value
      end
    end

    class BigDecimal < Value
      value :value, ::BigDecimal

      def to_hcl(level = 0)
        value.to_s
      end
    end

    class String < Value
      value :value, ::String

      def to_hcl(level = 0)
        "\"#{value}\""
      end
    end

    class Boolean < Value
      value :value, ::Object
    end

    class List < Value
      child :value, [Value]

      def to_hcl(level = 0)
        "[#{value.map(&:to_hcl).join(', ')}]"
      end
    end

    class Attribute < BaseNode
      child :key, Key
      child :value, Value
      child :line_comment, Comment
      child :lead_comments, [Comment]

      attr_accessor :inline

      def initialize(key:, value:, line_comment: nil, lead_comments: [], inline: false)
        @inline = inline
        super(key, value, line_comment, lead_comments)
      end

      def to_hcl(level = 0)
        attr_format = inline ? '%{key} %{value}' : '%{key} = %{value}'
        attr_hcl = indent(attr_format % { key: key.to_hcl, value: value.to_hcl(level) }, level, 1)
        lead_comment_hcl = indent(lead_comments.map(&:to_hcl).join("\n"), level)
        case
          when lead_comments.any? && !line_comment.nil?
            "\n%s\n%s %s" % [lead_comment_hcl, attr_hcl, indent(line_comment.to_hcl, level)]
          when lead_comments.any?
            "\n%s\n%s" % [lead_comment_hcl, attr_hcl]
          when !line_comment.nil?
            '%s %s' % [attr_hcl, indent(line_comment.to_hcl, level)]
          else
            attr_hcl
        end
      end
    end

    class Object < Value
      child :attributes, [Attribute]

      def to_hcl(level = 0)
        "{\n#{attributes.map { |a| a.to_hcl(level + 1) }.join("\n")}\n#{indent('}', level)}"
      end
    end

    class SectionNode < BaseNode
      child :attributes, [Attribute]
      child :comments, [Comment]

      def find_by_key(k)
        attributes.find { |a| a.key.value == k }
      end

      def comments_hcl
        "#{comments.map(&:to_hcl).join("\n")}\n"
      end

      def attributes_hcl
        "{\n#{attributes.map { |a| a.to_hcl(1) }.join("\n")}\n}"
      end
    end

    class Variable < SectionNode
      value :name, ::String

      def type
        find_by_key('type')
      end

      def default
        find_by_key('default')
      end

      def description
        find_by_key('description')
      end

      def to_hcl
        "#{comments_hcl}variable \"#{name}\" #{attributes_hcl}"
      end
    end

    class Module < SectionNode
      value :name, ::String

      def to_hcl
        "#{comments_hcl}module \"#{name}\" #{attributes_hcl}"
      end
    end

    class Resource < SectionNode
      value :type, ::String
      value :name, ::String

      def to_hcl
        "#{comments_hcl}resource \"#{type}\" \"#{name}\" #{attributes_hcl}"
      end
    end

    class Data < SectionNode
      value :type, ::String
      value :name, ::String

      def to_hcl
        "#{comments_hcl}data \"#{type}\" \"#{name}\" #{attributes_hcl}"
      end
    end


    class Locals < SectionNode
      def to_hcl
        "#{comments_hcl}locals #{attributes_hcl}"
      end
    end

    class Terraform < SectionNode
      def to_hcl
        "#{comments_hcl}terraform #{attributes_hcl}"
      end
    end

    class Provider < SectionNode
      value :name, ::String

      def to_hcl
        "#{comments_hcl}provider \"#{name}\" #{attributes_hcl}"
      end
    end

    class Output < SectionNode
      value :name, ::String

      def to_hcl
        "#{comments_hcl}output \"#{name}\" #{attributes_hcl}"
      end
    end
  end
end