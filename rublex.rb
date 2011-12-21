# Copyright 2011 Randy Carnahan <syntruth at gmail>
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to use this code in personal, non-commercial
# applications, unless permission from me is granted otherwise. Also,this
# code may not be redistributed without permission. The above is subject
# to the follow restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
#
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
#
# 3. This notice may not be removed or altered from any source distribution.

module RubLex

  GroupRE = /^\[(.+?)\](.*?)$/

  class RubLexError < Exception
  end

  class Rule
    attr :group
    attr :syllables
    attr :chance

    def initialize(group, syllables=[], chance=100)
      if syllables.is_a?(String)
        syllables = syllables.split(/\s+/)
      end

      @group     = group
      @syllables = syllables
      @chance    = chance.to_i
    end

    def choose
      syl = ""

      if (rand(100) + 1) <= @chance
        syl = @syllables[rand(@syllables.length)]
        syl.gsub!(/_/, " ")
      end

      return syl
    end
  end

  # The Special '_' space rule.
  SpaceRule = Rule.new(" ", [" "])

  class Lexicon
    attr :file
    attr :caps
    attr :verbose
    attr :chain

    def initialize(file, caps=false, verbose=false)
      @file    = file
      @caps    = caps
      @chain   = []
      @verbose = verbose

      get_rules()
    end

    def generate
      word = @chain.collect { |rule| rule.choose }.join("")
      word = word.capitalize if @caps
      return word
    end

    def reload
      get_rules()
    end

  private

    def get_rules
      current   = nil
      syllables = []
      rules     = {}

      File.open(@file) do |fp|
        fp.readlines.each do |line|
          line.gsub(/#.*/, '')

          match = line.match(GroupRE)

          if match
            current = match.captures.first

            if match.captures.last.strip.empty?
              next
            else
              line = match.captures.last.strip
            end
          end

          line.strip!

          next if line.empty?

          parts = line.split(/\s+/)

          if current == "syllable"
            if parts.empty?
              raise RubLexError, "Syllables sequence not defined!"
            end

            syllables = parts
            current   = nil
            next
          end

          unless current and not parts.empty?
            raise RubLexError, "Values outside of a syllable group: %s" % line
          end

          rules[current] = [] unless rules.has_key?(current)                

          parts.length.times do |i|
            part = parts[i]

            # If this is a number, convert it, then add that
            # many of the following syllable to the rules list.
            if part.match(/^\d/)
              part = part.to_i

              # If this is 0, that's an error.
              if part.zero?
                raise RubLexError, "Rule Error in line: %s" % line 
              end

              # Grab the next syllable. This will be nil if
              # i+1 is >= parts.length satisfying the if
              # block following.
              syl = parts[i+1]

              if syl
                # We subtract one, because we will be adding the
                # following syllable as well on the next iteration.
                (part - 1).times { rules[current].push(syl) } 
              end
            else
              rules[current].push(part)
            end
          end
        end
      end

      raise RubLexError, "No Syllables Given!" if syllables.empty?

      idx = 0

      while idx < syllables.length
        num  = 100
        syl  = syllables[idx]

        if syl.match(/^\d/)
          idx += 1
          num  = syl.to_i
          syl  = syllables[idx]

          if (num <= 0 or num > 100) or syl.nil?
            raise RubLexError, "Syllable Percentile Error: %s" % syllables[idx]
          end
        end

        if syl == "_"
          # Handle the special space rule.
          rule = SpaceRule
        elsif rules.has_key?(syl)
          rule = Rule.new(syl, rules[syl], num)
        else
          raise RubLexError, "No syllable group matches %s!" % syl
        end

        @chain.push(rule)
        idx += 1
      end

      if @verbose
        @chain.each do |rule|
          puts "%s (%s): %s" % [rule.group, rule.chance, rule.syllables.length]
        end
      end

      return self
    end
  end

# End Module
end

