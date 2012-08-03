#
# MySQL Manager - a utility to perform routine tasks on a MySQL database
# Copyright (C) 2012 Erik Osterman <e@osterman.com>
# 
# This file is part of MySQL Manager.
# 
# MySQL Manager is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# MySQL Manager is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with MySQL Manager.  If not, see <http://www.gnu.org/licenses/>.
#
require 'optparse'

module MysqlManager
  class MissingArgumentException < Exception; end

  class CommandLine
    attr_accessor :utilities

    def to_pattern(str)
      if str =~ /^\/(.*?)\/$/
        Regexp.new($1.to_s)
      else
        Regexp.new("^#{Regexp.escape(str)}$")
      end
    end

    def initialize
      @options = {}
      @options[:db] = {}
      @options[:log] = {}
      @options[:kill] = {}
      @options[:reload_my_cnf] = {}
      @options[:skip_replication_errors] = {}

      begin
        @optparse = OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} options"
          
        
          #
          # Killing options
          #
          @options[:kill][:execute] = false
          opts.on( '--kill', 'Kill queries based on specified criteria') do
            @options[:kill][:execute] = true
          end

          @options[:kill][:max_query_time] = -1
          opts.on( '--kill:max-query-time TIME', 'Kill queries that have been running for more than TIME') do |time|
            @options[:kill][:max_query_time] = time.to_i
          end

          @options[:kill][:user] = []
          opts.on( '--kill:user USER', 'Kill queries matching USER (repeatable)') do |user|
            @options[:kill][:user] << to_pattern(user) 
          end

          @options[:kill][:host] = []
          opts.on( '--kill:host HOST', 'Kill queries matching HOST (repeatable)') do |host|
            @options[:kill][:host] << to_pattern(host) 
          end

          @options[:kill][:query] = []
          opts.on( '--kill:query SQL', 'Kill queries matching SQL (repeatable)') do |sql|
            @options[:kill][:query] << to_pattern(sql) 
          end

          @options[:kill][:command] = []
          opts.on( '--kill:command COMMAND', 'Kill queries matching COMMAND (repeatable)') do |command|
            @options[:kill][:command] << to_pattern(command) 
          end

          @options[:kill][:state] = []
          opts.on( '--kill:state STATE', 'Kill queries matching STATE (repeatable)') do |state|
            @options[:kill][:state] << to_patterns(state) 
          end

          @options[:kill][:db] = []
          opts.on( '--kill:db DB', 'Kill queries matching DB (repeatable)') do |db|
            @options[:kill][:db] << to_pattern(db) 
          end

          #
          # Skip Replication Error options
          #
          @options[:skip_replication_errors][:execute] = false
          opts.on( '--skip-replication-errors', 'Skip replication errors based on specified criteria') do
            @options[:skip_replication_errors][:execute] = true
          end

          @options[:skip_replication_errors][:max_errors] = -1
          opts.on( '--skip-replication-errors:max-errors NUMBER', "Abort after encountering NUMBER of errors (default: #{@options[:skip_replication_errors][:max_errors]})") do |number|
            @options[:skip_replication_errors][:max_errors] = number.to_i
          end

          @options[:skip_replication_errors][:max_error_duration] = -1
          opts.on( '--skip-replication-errors:max-error-duration SECONDS', "Abort after attempting to recover after SECONDS elapsed (default: #{@options[:skip_replication_errors][:max_error_durration]})") do |seconds|
            @options[:skip_replication_errors][:max_error_duration] = seconds.to_i
          end

          @options[:skip_replication_errors][:min_healthy_duration] = -1
          opts.on( '--skip-replication-errors:min-healthy-duration SECONDS', "Abort after replication healthy for SECONDS elapsed (default: #{@options[:skip_replication_errors][:min_healthy_duration]})") do |seconds|
            @options[:skip_replication_errors][:min_healthy_duration] = seconds.to_i
          end

          @options[:skip_replication_errors][:log_frequency] = 10
          opts.on( '--skip-replication-errors:max-errors SECONDS', "Output replication status events every SECONDS elapsed (default: #{@options[:skip_replication_errors][:log_frequency]})") do |seconds|
            @options[:skip_replication_errors][:log_frequency] = seconds.to_i
          end
 
          #
          # Reload my.cnf options
          #
          @options[:reload_my_cnf][:execute] = false
          opts.on( '--reload-my-cnf', 'Reload my.cnf based on specified criteria') do
            @options[:reload_my_cnf][:execute] = true
          end


          @options[:reload_my_cnf][:config] = '/etc/my.cnf'
          opts.on( '--reload-my-cnf:config FILE', "Issue set 'SET GLOBAL' for each variable in FILE (default: #{@options[:reload_my_cnf][:config]})") do |file|
            @options[:reload_my_cnf][:config] = file
          end

          @options[:reload_my_cnf][:groups] = ['mysqld', 'mysqld_safe', 'mysql.server', 'mysql_server', 'server', 'mysql']
          opts.on( '--reload-my-cnf:groups GROUP', "Issue set 'SET GLOBAL' for each variable in FILE (default: #{@options[:reload_my_cnf][:groups].join(', ')})") do |group|
            @options[:reload_my_cnf][:groups] << group
          end


          #
          # Database connection options
          #
          @options[:db][:dsn] = 'DBI:Mysql:mysql:localhost'
          opts.on( '--db:dsn DSN', "DSN to connect to MySQL database (default: #{@options[:db][:dsn]})" ) do|dsn|
            @options[:db][:dsn] = dsn
          end

          @options[:db][:username] = 'root'
          opts.on( '--db:username USERNAME', "Username corresponding to DSN (default: #{@options[:db][:username]})" ) do|username|
            @options[:db][:username] = username
          end

          @options[:db][:password] = ""
          opts.on( '--db:password PASSWORD', "Password corresponding to DSN (default: #{@options[:db][:password]})" ) do|password|
            @options[:db][:password] = password
          end

          #
          # Logging options
          #
          @options[:log][:level] = Logger::INFO
          opts.on( '--log:level LEVEL', 'Logging level' ) do|level|
            @options[:log][:level] = Logger.const_get level.upcase
          end

          @options[:log][:file] = STDERR
          opts.on( '--log:file FILE', 'Write logs to FILE (default: STDERR)' ) do|file|
            @options[:log][:file] = File.open(file, File::WRONLY | File::APPEND | File::CREAT)
          end

          @options[:log][:age] = 7
          opts.on( '--log:age DAYS', "Rotate logs after DAYS pass (default: #{@options[:log][:age]})" ) do|days|
            @options[:log][:age] = days.to_i
          end

          @options[:log][:size] = 1024*1024*10
          opts.on( '--log:size SIZE', 'Rotate logs after the grow past SIZE bytes' ) do |size|
            @options[:log][:size] = size.to_i
          end

          # 
          # General options
          #
          @options[:dry_run] = false
          opts.on( '--dry-run', 'Do not run statements which affect the state of the database when executed' ) do
            @options[:dry_run] = true
          end


          opts.on( '-V', '--version', 'Display version information' ) do
            puts "MySQL Manager #{MysqlManager::VERSION}"
            puts "Copyright (C) 2012 Erik Osterman <e@osterman.com>"
            puts "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>"
            puts "This is free software: you are free to change and redistribute it."
            puts "There is NO WARRANTY, to the extent permitted by law."
            exit
          end

          opts.on( '-h', '--help', 'Display this screen' ) do
            puts opts
            exit
          end
        end

        @optparse.parse!

        raise MissingArgumentException.new("No action specified") if @options.select { |k,v| v.instance_of?(Hash) && v.has_key?(:execute) && v[:execute] == true }.size == 0
        @log = Logger.new(@options[:log][:file], @options[:log][:age], @options[:log][:size])
        @log.level = @options[:log][:level]
        @utilities = Utilities.new(@options[:db])
        @utilities.log = @log
        @utilities.dry_run = @options[:dry_run]
      rescue MissingArgumentException => e
        puts e.message
        puts @optparse
        exit (1)
      end
    end

    def execute
      @options.each do |type,options|
        next if options.instance_of?(Hash) && options.has_key?(:execute) && options[:execute] == false
        begin
          case type
          when :kill
            @log.debug("about to call kill_queries")
            @utilities.kill_queries(options)
          when :skip_replication_errors
            @log.debug("about to call skip_replication_errors")
            @utilities.skip_replication_errors(options)
          when :reload_my_cnf
            @log.debug("about to call reload_my_cnf")
            @utilities.reload_my_cnf(options)
          end
        rescue FileNotFoundException => e
          @log.fatal(e.message)
        rescue Interupt
          @log.info("Exiting")
        rescue Exception => e
          @log.fatal(e.message + e.backtrace.join("\n"))
        end
      end
    end
  end
end
