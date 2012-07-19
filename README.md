# MySQL Manager

MySQL Manager is a utility to perform routine tasks on a MySQL database. 

  * Continuously execute `SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1` and `START SLAVE` statements until replication is caught up (leaves slave in inconsistent state with master) 
  * Reload `my.cnf` without restarting MySQL (limited to dynamic variables)
  * Kill queries that match a set of criteria (execution time, user, db, state, command, host, query) using PCRE regexes or literal strings. 

## Installation

Add this line to your application's Gemfile:

    gem 'mysql_manager'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mysql_manager

## Usage

    Usage: mysql-manager options
            --kill                       Kill queries based on specified criteria
            --kill:max-query-time TIME   Kill queries that have been running for more than TIME
            --kill:user USER             Kill queries matching USER (repeatable)
            --kill:host HOST             Kill queries matching HOST (repeatable)
            --kill:query SQL             Kill queries matching SQL (repeatable)
            --kill:command COMMAND       Kill queries matching COMMAND (repeatable)
            --kill:state STATE           Kill queries matching STATE (repeatable)
            --kill:db DB                 Kill queries matching DB (repeatable)
            --skip-replication-errors    Skip replication errors based on specified criteria
            --skip-replication-errors:max-error-duration SECONDS
                                         Abort after attempting to recover after SECONDS elapsed (default: )
            --skip-replication-errors:min-healthy-duration SECONDS
                                         Abort after replication healthy for SECONDS elapsed (default: -1)
            --skip-replication-errors:max-errors SECONDS
                                         Output replication status events every SECONDS elapsed (default: 10)
            --reload-my-cnf              Reload my.cnf based on specified criteria
            --reload-my-cnf:config FILE  Issue set 'SET GLOBAL' for each variable in FILE (default: /etc/my.cnf)
            --reload-my-cnf:groups GROUP Issue set 'SET GLOBAL' for each variable in FILE (default: mysqld, mysqld_safe, mysql.server, mysql_server, server, mysql)
            --db:dsn DSN                 DSN to connect to MySQL database (default: DBI:Mysql:mysql:localhost)
            --db:username USERNAME       Username corresponding to DSN (default: root)
            --db:password PASSWORD       Password corresponding to DSN (default: )
            --log:level LEVEL            Logging level
            --log:file FILE              Write logs to FILE (default: STDERR)
            --log:age DAYS               Rotate logs after DAYS pass (default: 7)
            --log:size SIZE              Rotate logs after the grow past SIZE bytes
            --dry-run                    Do not run statements which affect the state of the database when executed
        -V, --version                    Display version information
        -h, --help                       Display this screen

## Examples

Kill all queries by user "api" that have been running longer than 30 seconds:

    mysql-manager --kill --kill:user api --kill:max-query-time 30 --log:level DEBUG --dry-run

Recover a MySQL Slave that has failed replication and wait for it to remain healthy (fully caught up to master) for 60 seconds.

    mysql-manager --skip-replication-errors --skip-replication-errors:min-healthy-duration 60 --log:level DEBUG

Reload `/etc/my.cnf` without restarting MySQL:

    mysql-manager --reload-my-cnf --reload-my-cnf:config /etc/my.cnf --log:level DEBUG
    
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
