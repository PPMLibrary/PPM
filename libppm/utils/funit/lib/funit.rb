begin
#  require 'rubygems'
  require 'fortran'
rescue LoadError
  STDERR.puts "gem install fortran"
  exit 1
end

require 'funit/compiler'
require 'funit/functions'
require 'funit/assertions'
require 'funit/testsuite'
require 'fileutils'

module Funit

  VERSION = '0.11.1'

  ##
  # run all tests

  def run_tests(prog_source_dirs=['.'])
    Compiler.new# a test for compiler env set (FIXME: remove this later)
    write_test_runner( test_files = parse_command_line )
    test_suites = []
    test_files.each{ |test_file|
      original_dir = Dir.pwd
      tf_dir = File.dirname(test_file)
      Dir.chdir tf_dir
      prog_source_dirs << tf_dir
      test_file = File.basename(test_file)
      tf_content = IO.read(test_file+'.fun')
      tf_content.scan(/test_suite\s+(\w+)(.*?)end\s+test_suite(.*)?/m).each{|ts|
        ts_name = $1
        ts_content = $2
        ts_trailing = $3
        if((!File.exist?(ts_name+"_fun.f")) || File.mtime(ts_name+"_fun.f") < File.mtime(test_file+".fun")) then
          if ( File.read('../../'+ts_name+'.f').match(/\s*module\s+#{ts_name}/i) ) then
            TestSuite.new(ts_name, ts_content, ts_trailing, false)
          else
            TestSuite.new(ts_name, ts_content, ts_trailing, true)
          end
        end
        test_suites.push(ts_name)
      }
      Dir.chdir original_dir
    }
    compile_tests(test_suites,prog_source_dirs)
    exit 1 unless system "PATH=.:$PATH TestRunner"
    clean_genFiles
  end

  ##
  # remove files generated by fUnit

  def clean_genFiles
    module_names = Dir["**/*.fun"].map{|mn| mn.chomp(".fun")}
    tbCancelled = module_names.map{|mn| mn+"_fun."} + ["TestRunner."]
    tbCancelled = tbCancelled.map{|tbc| [tbc+"f",tbc+"o",tbc+"MOD"]}.flatten
#    tbCancelled += Dir["**/TestRunner"]
    tbCancelled += Dir["**/__TestRunner.f"]
    tbCancelled += Dir["**/makeTestRunner"]
    tbCancelled = (tbCancelled+tbCancelled.map{|tbc| tbc.downcase}).uniq
    FileUtils.rm_f(tbCancelled)
  end

  ##
  # prints a usage help for the user

  def print_help
    puts <<-END_OF_HELP
      To use fUnit, type:
        funit [-options] [test_file_name(s)]
      The argument(s) is optional. If no argument is given, then all the .fun files inside the working directory will be used.

      The options are:
        --clean                   => To remove the files generated by fUnit
        -h, --help                => Prints this help
        -s <dir>, --source <dir>  => To specify a directory for the non-test source
    END_OF_HELP
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
