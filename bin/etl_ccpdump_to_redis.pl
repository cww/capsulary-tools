# Copyright (c) 2012 Colin Wetherbee
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#!/usr/bin/perl

use common::sense;

use FindBin qw($Bin $Script);
use Getopt::Long;
use JSON::PP;
use Log::Log4perl qw(:easy);

use Capsulary::DB::Redis;
use Capsulary::DB::SqlServer;

BEGIN
{
    Log::Log4perl->easy_init($INFO);

    # The SQL Server ODBC driver sometimes craps out with "Unexpected EOF from
    # the server" if this isn't specified.
    $ENV{TDSVER} = '7.0';
}

use constant REDIS_BASE => 'eve';
use constant SCHEMA => 'dbo';

my $etl;
my $opt_dsn;
my $opt_username;
my $opt_password;
my $opt_help;
my $opt_redis_host = 'localhost';
my $opt_redis_port = 6379;
my @opt_tables;
my %_opt_tables;
my @opt_drop;
my $opt_drop_all;
my $opt_debug_output;
my $opt_dry_run;
my $opt_small;

sub usage
{
    say STDERR 'FATAL: ', @_ if @_;

    say "Usage: $Script <-d DSN> <-u USERNAME> <-p PASSWORD>";
    say "Required:";
    say "    -d DSN         The DSN, as defined in your odbc.ini file,";
    say "                   to use for SQL Server";
    say "    -u USERNAME    The username to use for SQL Server";
    say "    -p PASSWORD    The password to use for SQL Server";
    say "Optional:";
    say "    -h                 Print this helpful usage information";
    say "    --redis-host HOST  The Redis hostname [localhost]";
    say "    --redis-port PORT  The Redis port [6379]";
    say "    --tables T1,T2,... A list of tables to export (do not include";
    say "                       \"dbo\" schema prefix) [all tables]";
    say "Destructive:";
    say "    --drop T1,T2,...   A list of tables whose data to delete from";
    say "                       the Redis database before performing any";
    say "                       other operations";
    say "    --drop-all         Same as above but with all tables";
    say "Debug:";
    say "    --debug        Enable debug (trace, actually) output";
    say "    --dry-run      Do not connect to anything";
    say "    --small        Only process one row from each table";

    exit -1;
}

sub parse_etl_json
{
    my $json = JSON::PP->new();
    my $json_file = "$Bin/etl.json";
    eval
    {
        my $fh;
        open($fh, '<', $json_file) or die $!;
        while (my $line = <$fh>)
        {
            $json->incr_parse($line);
        }
        close($fh);
        $etl = $json->incr_parse()->{etl};
    };
    die "unable to parse file [$json_file]: $@" if $@;
}

sub parse_opts
{
    my $result = GetOptions
    (
        'dsn|d=s'      => \$opt_dsn,
        'username|u=s' => \$opt_username,
        'password|p=s' => \$opt_password,
        'debug'        => \$opt_debug_output,
        'help|h'       => \$opt_help,
        'redis-host=s' => \$opt_redis_host,
        'redis-port=s' => \$opt_redis_port,
        'tables=s'     => \@opt_tables,
        'drop=s'       => \@opt_drop,
        'drop-all'     => \$opt_drop_all,
        'dry-run'      => \$opt_dry_run,
        'small'        => \$opt_small,
    );

    usage() if $opt_help;
    usage('Must specify a DSN') unless $opt_dsn;
    usage('Must specify a username') unless $opt_username;
    usage('Must specify a password') unless $opt_password;
    usage('Cannot specify --drop and --drop-all together') if
        $opt_drop_all && scalar(@opt_drop) > 0;

    Log::Log4perl->easy_init($TRACE) if $opt_debug_output;

    # Because Getopt::Long allows multi-parameter options to be specified as
    # "--foo 1 --foo 2 --foo 3" and as "--foo 1,2,3", we need to merge all the
    # values into a single-value-per-element list (and then populate a hash,
    # too, for fast lookups).
    if (@opt_tables > 0)
    {
        @opt_tables = split(/,/, join(q{,}, @opt_tables));
        %_opt_tables = map { $_ => 1 } @opt_tables;
    }

    my %valid_table_names = map { $_->{__table} => 1 } @$etl;
    for my $table_name (@opt_tables)
    {
        TRACE "Checking table name [$table_name] for validity.";
        die "Table [$table_name] is invalid" unless
            $valid_table_names{$table_name};
    }

    if (@opt_drop > 0)
    {
        @opt_drop = split(/,/, join(q{,}, @opt_drop));
    }

    if ($opt_drop_all)
    {
        @opt_drop = keys %valid_table_names;
    }

    DEBUG "Opt: DSN = $opt_dsn";
    DEBUG "Opt: Username = $opt_username";
    DEBUG "Opt: Password = $opt_password";
    DEBUG "Opt: Redis Host = $opt_redis_host";
    DEBUG "Opt: Redis Port = $opt_redis_port";
    DEBUG 'Opt: Tables = ' . join(q{, }, @opt_tables);
    DEBUG 'Opt: Drop Tables = ' . join(q{, }, @opt_drop);
}

parse_etl_json();
parse_opts();

my $sqlserver = Capsulary::DB::SqlServer->new
({
    dsn      => $opt_dsn,
    username => $opt_username,
    password => $opt_password,
});
my $dbh;
if (!$opt_dry_run)
{
    $sqlserver->connect();
    $dbh = $sqlserver->get_handle();
}

my $redis = Capsulary::DB::Redis->new
({
    host => $opt_redis_host,
    port => $opt_redis_port,
});
my $rh;
if (!$opt_dry_run)
{
    $redis->connect();
    $rh = $redis->get_handle();
}

for my $table (@opt_drop)
{
    my @table_defs = grep { $_->{__table} eq $table } @$etl;
    die "Invalid configuration: table $table specified more than once" if
        scalar(@table_defs) > 1;

    # Create a selector that looks like "eve.solar_system.*".
    my $selector = join
    (
        q{.},
        REDIS_BASE,
        $table_defs[0]->{__reference_name},
        q{*},
    );

    DEBUG "Searching for keys to delete with selector [$selector]";

    if ($opt_dry_run)
    {
        DEBUG 'Dry run: not searching for or deleting keys.';
        next;
    }

    my @keys = $rh->keys($selector);
    for my $key (@keys)
    {
        DEBUG "Deleting key [$key]";
        $rh->del($key);
    }
}

for my $table_ref (@$etl)
{
    # If the user specified a list of tables on the command-line, then only
    # process the tables that were specified.
    next if @opt_tables > 0 && !$_opt_tables{$table_ref->{__table}};

    my $table_name = join(q{.}, SCHEMA, $table_ref->{__table});
    INFO "Processing table [$table_name]";
    my $primary_key_name = $table_ref->{__primary_key};
    my $reference_name = $table_ref->{__reference_name};

    my $sql = $opt_small ?
              qq{SELECT TOP 1 * FROM $table_name} :
              qq{SELECT * FROM $table_name};
    DEBUG "Generated SQL: $sql";
    if ($opt_dry_run)
    {
        DEBUG 'Dry run: not executing SQL.';
        next;
    }
    my $sth = $dbh->prepare($sql);

    $sth->execute();
    my $i_row = 0;
    while (my $row_ref = $sth->fetchrow_hashref())
    {
        # Handle each key/value pair in this row.
        while (my ($key, $value) = each %$row_ref)
        {
            if (!defined $value)
            {
                TRACE "Skipping null value for key [$key].";
                next;
            }
            
            # The key looks like "eve.type.123456.name".
            my $redis_key = join
            (
                q{.},
                REDIS_BASE,
                $table_ref->{__reference_name},
                $row_ref->{$primary_key_name},
                $table_ref->{$key},
            );
            TRACE "Setting key [$redis_key]->[$value].";
            $rh->set($redis_key, $value);
        }

        # Handle backrefs.
        my $backrefs_ref = ref $table_ref->{__backref} eq 'HASH' ?
                           [ $table_ref->{__backref} ] :
                           $table_ref->{__backref};
        for my $backref_ref (@$backrefs_ref)
        {
            # The key looks like "eve.type.by_name.Foo Bar Baz".
            my $redis_key = join
            (
                q{.},
                REDIS_BASE,
                $table_ref->{__reference_name},
                'by_' . $backref_ref->{by},
                $row_ref->{$backref_ref->{referrer}},
            );
            my $value = $row_ref->{$primary_key_name};
            TRACE "Adding backref [$redis_key]->[$value].";
            $rh->sadd($redis_key, $value);
        }

        ++$i_row;
    }

    INFO "Processed [$i_row] records.";

    if (defined($sth->err()))
    {
        WARN('ODBC: ' . $sth->errstr()) if $sth->err() eq 0;
        INFO('ODBC: ' . $sth->errstr()) if $sth->err() eq q{};
    }

    $sth->finish();
}

if (!$opt_dry_run)
{
    $sqlserver->disconnect();
    $redis->disconnect();
}
