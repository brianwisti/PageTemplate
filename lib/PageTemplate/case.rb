# case.rb
#
# This is a demonstration of adding a non-default command to
# PageTemplate's default glossary.
#
# Note that it adds itself to the glossary =).

class PageTemplate
  # CaseCommand provides switch-command functionality.
  # [% case variable %]
  # [% when literal1 %]
  # [% when literal2 %]
  # [% when literal3 %]
  # [% else %]
  # [% end %]
  class CaseCommand < StackableCommand
    @modifier = :when
    @closer   = :end

    attr_reader :current_case
    # +command+ is a variable that is evaluated against the namespace
    # on execution, and then tested against the literals of when. It
    # must return a string literal.
    def initialize(value)
      @called_as = 'case'
      @value = value
      @blocks = {}
      @current_case = nil
      @default = BlockCommand.new
    end
    # Adds a command to the current case, or to the 'else'
    def add(command)
      unless @current_case
        @default.add command
      else
        @blocks[@current_case].add command
      end
    end
    # 'when' and 'else' modify this command.
    def when(value)
      @current_case = value
      @blocks[value] = BlockCommand.new unless @blocks.has_key?(value)
    end
    def else
      @current_case = nil
      return true
    end
    # If namespace.get(@value) exists in the 'when' clauses, then
    # print out that block.
    def output(namespace=nil)
      val = namespace.get(@value,false)
      if @blocks.has_key?(val)
        @blocks[val].output(namespace)
      else
        @default.output(namespace)
      end
    end
    def to_s
      str = "[ Case: "
      @blocks.each do |key,val|
        str << " #{key}: [#{val}]"
      end
      str << " else #{@default.to_s}"
      str << " ]"
    end
  end
  DefaultGlossary.define(/^case (\w+(?:\.\w+)*)$/) { |match,parser|
    CaseCommand.new(match[1])
  }
  if PageTemplate.constants.include?('HTGlossary')
    HTGlossary.define(/^tmpl_case (?:NAME=)?(\w+(?:\.\w+\?)*)$/) { |m,parser|
      CaseCommand.new(m[1])
    }
  end
end
