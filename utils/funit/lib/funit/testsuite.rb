require 'funit'

module Funit

  include Assertions # FIXME

  ##
  # Create testsuite wrapper code

  class TestSuite < File

    KEYWORDS = Regexp.union(/^\s*(end\s+)?(setup|teardown|test|init|finalize)/i,Assertions::ASSERTION_PATTERN)
    COMMENT_LINE = /^\s*!/
    FORTRAN_USE = /^\s*USE\s+(\w+)/i

    include Funit #FIXME

    def initialize( suite_name, suite_content, trailing_code, wrap_with_module )
      @line_number = 'blank'
      @suite_name = suite_name
      @suite_content = suite_content
      @trailing_code = trailing_code
      return nil unless funit_exists?(suite_name)
      File.delete(suite_name+"_fun.f") if File.exists?(suite_name+"_fun.f")
      super(suite_name+"_fun.f","w")
      @init, @finalize, @tests, @setup, @teardown = [], [], [], [], []
      @arglists = {}
      header
      @wrap_with_module = wrap_with_module
      module_wrapper if @wrap_with_module
      top_wrapper
      expand
      close
    end

    def header
      puts <<-HEADER
! #{@suite_name}_fun.f - a unit test suite for #{@suite_name}.f
!
! #{File.basename $0} generated this file from #{@suite_name}.fun

      HEADER
    end

    def module_wrapper
      puts <<-MODULE_WRAPPER

MODULE #{@suite_name}_mod
CONTAINS
  INCLUDE '#@suite_name.f'
END MODULE #{@suite_name}_mod

      MODULE_WRAPPER
    end

    def top_wrapper
      puts "MODULE #{@suite_name}_fun"

      puts "  USE ppm_module_mpi"
      #FIXME (we want to check if the .fun file is a ppm module file
      # in which case we assume that we want to USE that module)
      # Otherwise, we do nothing and no module is loaded by default.
      if File.exists?("../../#{@suite_name}.f")
        puts "  USE #{ @wrap_with_module ? @suite_name+'_mod' : @suite_name }"
      end

      funit_contents = @suite_content.split("\n")
      while (line = funit_contents.shift) && line !~ /^\s*#.*/i && line !~/^\s*IMPLICIT\s+(\w+)/i && line !~ KEYWORDS
        puts line if line.match FORTRAN_USE
      end

      puts <<-TOP

  IMPLICIT NONE

  PRIVATE

  INTEGER :: numTests         = 0
  INTEGER :: numAsserts       = 0
  INTEGER :: numAssertsTested = 0
  INTEGER :: numFailures      = 0
  INTEGER :: funit_rank
  INTEGER :: funit_comm
  INTEGER :: funit_info
  INTEGER :: log

  LOGICAL :: noAssertFailed

  PUBLIC :: test_#@suite_name

      TOP
    end

    def expand
      funit_contents = @suite_content.split("\n")
      @funit_total_lines = funit_contents.length

      while (line = funit_contents.shift)
        if line !~ /^\s*use*/i && line.length > 1
          break
        end
      end
      funit_contents.unshift line

      while (line = funit_contents.shift) && line !~ KEYWORDS
        puts line if line !~ /\s*MPIF.H*/i && line !~ /\s*IMPLICIT*/i
      end

      funit_contents.unshift line

      puts "CONTAINS\n\n"

      while (line = funit_contents.shift)
        case line
        when COMMENT_LINE
          puts line
        when /^\s*init/i
          add_to_init funit_contents
        when /^\s*finalize/i
          add_to_finalize funit_contents
        when /^\s*setup/i
          add_to_setup funit_contents
        when /^\s*teardown/i
          add_to_teardown funit_contents
        when /^\s*Xtest\s+(\w+)/i
          ignore_test($1,funit_contents)
        when /^\s*test\s+(\w+)(.*)/i
          @tname    = $1
          @leftover = $2
          if (@leftover =~ /\(/ ) then
            @leftover += funit_contents.shift while (@leftover !~ /\)/)
          end
          a_test(@tname,funit_contents,@leftover)
        when /^\s*test/i
          syntax_error "no name given for test", @suite_name
        when /^\s*end\s+(setup|teardown|test)/i
          syntax_error "no matching #$1 for an #$&", @suite_name
        when Assertions::ASSERTION_PATTERN
          syntax_error "#$1 assertion not in a test block", @suite_name
        else
          puts line
        end
      end
    end

    def add_to_init funit_contents
      while (line = funit_contents.shift) && line !~ /end\s+init/i
        @init.push line
      end
    end

    def add_to_finalize funit_contents
      while (line = funit_contents.shift) && line !~ /end\s+finalize/i
        @finalize.push line
      end
    end

    def add_to_setup funit_contents
      while (line = funit_contents.shift) && line !~ /end\s+setup/i
        @setup.push line
      end
    end

    def add_to_teardown funit_contents
      while (line = funit_contents.shift) && line !~ /end\s+teardown/i
        @teardown.push line
      end
    end

    def ignore_test test_name, funit_contents
      warning("Ignoring test: #{test_name}", @suite_name)
      line = funit_contents.shift while line !~ /end\s+test/i
    end

    def a_test test_name, funit_contents, argument_list
      @test_name = test_name
      @tests.push test_name
      syntax_error("test name #@test_name not unique",@suite_name) if (@tests.uniq!)

      if (!argument_list.empty?) then
        argument_list =~ /\(\{(.*)\}\)/
        argsets = $1.split(/\}\s*,\s*\{/)
        @arglists[@test_name] = argsets
      end

      puts "  SUBROUTINE #{test_name}\n\n"

      num_of_asserts = 0

      while (line = funit_contents.shift) && line !~ /(end\s+test|contains)/i
        case line
        when COMMENT_LINE
          puts line
        when Assertions::ASSERTION_PATTERN
          @line_number = @funit_total_lines - funit_contents.length
          num_of_asserts += 1
          puts send( $1.downcase, line )
        else
          puts line
        end
      end

      warning("no asserts in test", @suite_name) if num_of_asserts == 0

      puts "\n  numTests = numTests + 1\n\n"

      if line =~ /contains/i
        puts line
        while (line = funit_contents.shift) && line !~ /end\s+test/
          puts line
        end
      end

      puts "  END SUBROUTINE #{test_name}\n\n"
    end

    def close
      puts "\n"
      puts "  SUBROUTINE funit_init"
      puts @init
      puts "  END SUBROUTINE funit_init\n\n"

      puts "  SUBROUTINE funit_setup"
      puts @setup
      puts "  noAssertFailed = .TRUE."
      puts "  END SUBROUTINE funit_setup\n\n"

      puts "  SUBROUTINE funit_teardown"
      puts @teardown
      puts "  END SUBROUTINE funit_teardown\n\n"

      puts "  SUBROUTINE funit_finalize"
      puts @finalize
      puts "  END SUBROUTINE funit_finalize\n\n"

      puts <<-NEXTONE

  SUBROUTINE test_#{@suite_name}( nTests, nAsserts, nAssertsTested, nFailures, lfh, rank, comm )

  IMPLICIT NONE

  INTEGER :: nTests
  INTEGER :: nAsserts
  INTEGER :: nAssertsTested
  INTEGER :: nFailures
  INTEGER :: lfh
  INTEGER :: rank
  INTEGER :: comm

  log = lfh
  funit_rank = rank
  funit_comm = comm

  CALL funit_init

      NEXTONE

      @tests.each do |test_name|
        if @arglists.has_key? test_name then
          puts "\n  WRITE(log,*) 'starting a test with an arglist...'"
          @arglists[test_name].each do |args|
            final_list = [{}]
            args.split(/(?!\[[^\]]*),(?![^\[]*\])/i).each do |arg|
              arg =~ /(.*):(.*)/
              name = $1
              name.strip!
              value = $2
              value.strip!
              if value =~ /\[(.*)\]/ then
                new_final = []
                $1.split(',').each do |val|
                  val.strip!
                  final_list.each do |set|
                    new_set = set.clone
                    new_set[name] = val
                    new_final.push(new_set)
                  end
                end
                final_list = new_final
              else
                final_list.each do |set|
                  set[name] = value
                end
              end
            end
            final_list.each do |arl|
              puts "\n  WRITE(log,*) 'setting up...'"
              puts "  CALL funit_setup"
              puts "  WRITE(log,*) 'Entering #{test_name}, arglist #{arl}'\n"
              arl.each do |var,val|
                puts "  #{var} = #{val}"
              end
              puts "  CALL #{test_name}"
              puts "  WRITE(log,*) 'Leaving #{test_name}, arglist #{arl}'\n"
              puts "  CALL funit_teardown"
              puts "  WRITE(log,*) 'cleaned up...'"
            end
          end
        else
          puts "\n  WRITE(log,*) 'setting up...'"
          puts "  CALL funit_setup"
          puts "  WRITE(log,*) 'Entering #{test_name}...'\n"
          puts "  CALL #{test_name}"
          puts "  WRITE(log,*) 'Leaving #{test_name}...'\n"
          puts "  CALL funit_teardown"
          puts "  WRITE(log,*) 'cleaned up...'"
        end
      end

      puts <<-LASTONE

  CALL funit_finalize

  nTests          = numTests
  nAsserts        = numAsserts
  nAssertsTested  = numAssertsTested
  nFailures       = numFailures

  END SUBROUTINE test_#{@suite_name}

END MODULE #{@suite_name}_fun

      LASTONE

      puts @trailing_code
      super
    end

  end

end

#--
# Copyright 2006-2007 United States Government as represented by
# NASA Langley Research Center. No copyright is claimed in
# the United States under Title 17, U.S. Code. All Other Rights
# Reserved.
#
# This file is governed by the NASA Open Source Agreement.
# See License.txt for details.
#++
