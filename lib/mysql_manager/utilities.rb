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
require 'dbi'
require 'logger'
require 'parseconfig'

module MysqlManager
  class FileNotFoundException < Exception; end

  class Utilities
    attr_accessor :dbh, :log, :dry_run

    def initialize(options = {})
      options[:dsn] ||= "DBI:Mysql:mysql:localhost"
      options[:username] ||= "root"
      options[:password] ||= ""

      @log = Logger.new(STDERR)

      # connect to the MySQL server
      @dbh = DBI.connect(options[:dsn], options[:username], options[:password])
    end

    def kill_queries(options = {})
      options[:max_query_time] ||= -1
      options[:user] ||= []
      options[:host] ||= []
      options[:query] ||= []
      options[:command] ||= []
      options[:state] ||= []
      options[:db] ||= []

      @dbh.execute("SHOW FULL PROCESSLIST") do |sth|
        sth.fetch_hash() do |row| 
          next if row['Command'] == 'Binlog Dump'
          next if row['User'] == 'system user'

          results = []
          options.each_pair do |field,criteria|
            case field
            when :max_query_time
              if criteria >= 0
                if row['Time'].to_i > criteria
                  results << true
                else
                  results << false
                end
              end
            when :user, :host, :query, :command, :state, :db
              
              col = field == :query ? 'Info' : field.to_s.capitalize

              if criteria.length > 0
                matched = false
                criteria.each do |pattern|
                  if pattern.match(row[col])
                    matched = true
                    break
                  end
                end
                #puts "#{row[col]} #{criteria.inspect} == #{matched}"
                results << matched
              end
            end
          end
          # Some conditions need to apply
          #puts results.inspect
          if results.length > 0
            # None of them may be false
            unless results.include?(false)
              begin
                @log.info("Killing id:#{row['Id']} db:#{row['db']} user:#{row['User']} command:#{row['Command']} state:#{row['State']} time:#{row['Time']} host:#{row['Host']} query:#{row['Info']} rows_sent:#{row['Rows_sent']} rows_examined:#{row['Rows_examined']} rows_read:#{row['Rows_read']}")
                @dbh.do("KILL #{row['Id']}") unless @dry_run
              rescue DBI::DatabaseError => e
                @log.warn(e.message)
              end
            end
          end
        end
      end
    end

    def reload_my_cnf(options = {})
      options[:config] ||= '/etc/my.cnf'
      options[:groups] ||= ['mysqld', 'mysqld_safe', 'mysql.server', 'mysql_server', 'server', 'mysql']

      variables = {}
      @dbh.execute("SHOW VARIABLES") do |sth|
        sth.fetch_hash() do |row| 
          variables[row['Variable_name']] = row['Value']
        end
      end
      unless File.exists?(options[:config])
        raise FileNotFoundException.new("Unable to open file #{options[:config]}")
      end
      
      my_cnf = ParseConfig.new(options[:config])
      my_cnf.groups.each do |group|
      if options[:groups].include?(group)
          @log.debug("loading values from [#{group}]")
          my_cnf[group].each_pair do |k,v|
            next if v.nil? || v.empty?
            if variables.has_key?(k)
              begin
                v = v.to_s
                v = v.to_i if v =~ /^(\d+)$/
                v = $1.to_i * (1024) if v =~ /^(\d+)K$/
                v = $1.to_i * (1024*1024) if v =~ /^(\d+)M$/
                v = $1.to_i * (1024*1024*1024) if v =~ /^(\d+)G$/
                if v.instance_of?(Integer) || v.instance_of?(Fixnum)
                  sql = "SET GLOBAL #{k} = #{v}"
                else
                  sql = "SET GLOBAL #{k} = '#{v}'"
                end
                @dbh.do(sql) unless @dry_run
                @log.info("set #{k}=#{v}")
              rescue DBI::DatabaseError => e
                @log.debug(@dbh.last_statement)
                @log.warn(e.message)
              end
            end
          end
        end 
      end
    end

    def skip_replication_errors(options = {})
      options[:max_errors] ||= -1
      options[:max_error_duration] ||= -1
      options[:min_healthy_duration] ||= -1
      options[:log_frequency] ||= 10

      begin
        # get server version string and display it
        max_seconds_behind = 0
        t_start = Time.now.to_f
        t_last_error = nil
        t_last_error_elapsed = 0
        t_last_log = 0
        t_elapsed = 0
        t_recovered = 0
        errors = 0
        while (options[:max_errors] < 0 || errors < options[:max_errors]) && (options[:max_error_duration] < 0 || t_last_error_elapsed < options[:max_error_duration])
          @dbh.execute("SHOW SLAVE STATUS") do |sth|
            t_now = Time.now.to_f
      
            sth.fetch_hash() do |row| 
              seconds_behind = row['Seconds_Behind_Master']
              if seconds_behind.nil?
                @log.info("replication broken")
                @log.info("last error: #{row['Last_Error'].gsub(/\r?\n/, '')}")

                @dbh.do("SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1") unless @dry_run
                @dbh.do("START SLAVE")
                errors += 1
                max_seconds_behind = 0
                t_last_error = t_now
              elsif seconds_behind == 0
                t_recovered = t_now if t_recovered == 0
                if t_last_log == 0 || t_now - t_last_log > options[:log_frequency]
                  @log.info("fully caught up with master")
                  t_last_log = t_now
                end
                if (t_min_healthy_duration >=0) && (t_now - t_recovered > t_min_healthy_duration)
                  @log.info("satisfied health duration window")
                  break
                end
              else
                seconds_behind = seconds_behind.to_f
                t_recovered = 0
                t_last_error_elapsed = t_last_error.nil? ? 0 : t_now - t_last_error
                t_elapsed = t_now - t_start
                max_seconds_behind = [max_seconds_behind, seconds_behind].max
                t_catchup = max_seconds_behind - seconds_behind
                t_rate = t_elapsed == 0 ? 1 : t_catchup/t_elapsed
                t_left = t_rate > 0 ? seconds_behind/t_rate : 0
                if t_left > 60*60
                  t_left_str = sprintf('%.2f hours', t_left/(60*60))
                elsif t_left > 60
                  t_left_str = sprintf('%.2f mins', t_left/60)
                else
                  t_left_str = sprintf('%.2f secs', t_left)
                end
                if t_last_log == 0 || t_now.to_f - t_last_log.to_f > options[:log_frequency]
                  @log.info("#{seconds_behind} seconds behind master; #{t_catchup} seconds caught up; #{sprintf('%.2f', t_rate)} seconds/second; #{t_left_str} left; #{errors} errors; last error #{sprintf('%.2f', t_last_error_elapsed)} seconds ago")
                  t_last_log = t_now
                end

                sleep 0.100
              end
            end
          end
        end
      rescue Interrupt
        @log.info("Aborted by user")
      rescue DBI::DatabaseError => e
        @log.error("Error code: #{e.err}: #{e.errstr}")
      end
    end
  end
end
