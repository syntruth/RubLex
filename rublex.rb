#!/usr/bin/env ruby
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

    # By default, this class expects to get it's lexicon
    # rules from a file. Subclass and overwrite get_rules()
    # to obtain the rules from another source.
    # That is the reason get_rules() is a private method;
    # use load() to obtain the rules.
    def initialize(source, caps=false, verbose=false)
      @source  = source
      @caps    = caps
      @chain   = []
      @verbose = verbose

      self.load()
    end

    def generate
      word = @chain.inject("") do |w, rule|
        w += rule.choose 
      end

      return @caps ? word.capitalize : word
    end

    def load
      return get_rules()
    end

  private

    def get_rules
      # This regex matchs groups in []'s followed
      # by any option text that is meant to be parsed.
      group_re  = /^\[(.+?)\](.*?)$/

      current   = nil # Which group are we working on?
      syllables = []  # Holds the Syllables for further parsing.
      rules     = {}  # Hash of the syllable rule groups.
      idx       = 0   # For using index access in our list loops.
      linenum   = 0   # For reporting errors better.

      File.open(@source) do |fp|
        fp.readlines.each do |line|
          linenum += 1

          line.gsub(/#.*/, '')

          if @verbose and not line.strip.empty?
            puts "Working on line:\n    %s - %s" % [linenum, line]
          end

          match = line.match(group_re)

          if match
            current = match.captures.first
            line    = match.captures.last
          end

          line.strip!

          next if line.empty?

          parts = line.split(/\s+/)

          if current == "syllable"
            if parts.empty?
              raise RubLexError, 
                    "%s - Syllables sequence not defined!" % linenum
            end

            syllables = parts
            current   = nil
            next
          end

          if current.nil? and parts.empty?
            raise RubLexError, "Values outside of group: %s - %s" % [linenum, line]
          end

          unless rules.has_key?(current)                
            rules[current] = []
          end

          idx = 0 # Reset the index counter

          while idx < parts.length
            part = parts[idx]

            # If this is a number, convert it, then add that
            # many of the following syllable to the rules list.
            if part.match(/^\d/)
              num = part.to_i

              # If this is 0, that's an error.
              if num.zero?
                raise RubLexError, "Rule Error in line: %s - %s" % [linenum, line]
              end

              # Increment idx to grab the next part.
              idx += 1

              # Grab the next syllable. This will be nil if
              # idx is >= parts.length satisfying the if
              # block following.
              syl = parts[idx]

              if syl
                num.times do
                  rules[current].push(syl)
                end
              end

            else
              rules[current].push(part)
            end

            idx += 1
          end
        end
      end

      raise RubLexError, "No Syllables Given!" if syllables.empty?

      idx = 0 # Reset the index

      while idx < syllables.length
        num = 100
        syl = syllables[idx]

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
        puts "Syllable Groups:"
        @chain.each do |rule|
          puts "  %s (%s): %s" % [rule.group, rule.chance, rule.syllables.length]
        end
      end

      return self
    end
  end

# End Module
end

# Main for testing
#f = "lexes/test.lex"
#lex = RubLex::Lexicon.new(f, true, true)
#5.times { puts lex.generate }



