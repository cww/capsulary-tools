#!/usr/bin/perl

use common::sense;

use FindBin qw($Script);
use Getopt::Long;
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

use constant BASE => 'eve';
use constant ETL =>
[
    {
        '__reference_name' => 'type',
        '__table' => 'dbo.invTypes',
        '__primary_key' => 'typeID',
        '__backref' =>
        {
            by       => 'name',
            referrer => 'typeName',
        },
        'typeID' => 'id',
        'groupID' => 'group_id',
        'typeName' => 'name',
        'description' => 'description',
        'graphicID' => 'graphic_id',
        'radius' => 'radius',
        'mass' => 'mass',
        'volume' => 'volume',
        'capacity' => 'capacity',
        'portionSize' => 'portion_size',
        'raceID' => 'race_id',
        'basePrice' => 'base_price',
        'published' => 'published',
        'marketGroupID' => 'market_group_id',
        'chanceOfDuplicating' => 'chance_of_duplicating',
        'iconID' => 'icon_id',
    },
];

my $opt_dsn;
my $opt_username;
my $opt_password;
my $opt_help;
my $opt_redis_host = 'localhost';
my $opt_redis_port = 6379;
my $opt_debug_output;

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
    say "    --debug            Enable debug output";
    say "    -h                 Print this helpful usage information";
    say "    --redis-host HOST  The Redis hostname [localhost]";
    say "    --redis-port PORT  The Redis port [6379]";

    exit -1;
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
    );

    usage() if $opt_help;
    usage('Must specify a DSN') unless $opt_dsn;
    usage('Must specify a username') unless $opt_username;
    usage('Must specify a password') unless $opt_password;

    Log::Log4perl->easy_init($DEBUG) if $opt_debug_output;

    DEBUG "Opt: DSN = $opt_dsn";
    DEBUG "Opt: Username = $opt_username";
    DEBUG "Opt: Password = $opt_password";
    DEBUG "Opt: Redis Host = $opt_redis_host";
    DEBUG "Opt: Redis Port = $opt_redis_port";
}

parse_opts();

my $sqlserver = Capsulary::DB::SqlServer->new
({
    dsn      => $opt_dsn,
    username => $opt_username,
    password => $opt_password,
});
$sqlserver->connect();
my $dbh = $sqlserver->get_handle();

my $redis = Capsulary::DB::Redis->new
({
    host => $opt_redis_host,
    port => $opt_redis_port,
});
my $rh = $redis->get_handle();

for my $table_ref (@{+ETL})
{
    my $table_name = $table_ref->{__table};
    INFO "Processing table [$table_name]";
    my $primary_key_name = $table_ref->{__primary_key};
    my $reference_name = $table_ref->{__reference_name};

    my @columns = grep { !/^__/ } keys %$table_ref;
    my $column_clause = join(q{, }, @columns);
    my $sql = qq{SELECT * FROM $table_name};
    my $sth = $dbh->prepare($sql);

    DEBUG "Running SQL: $sql";
    $sth->execute();
    my $i_row = 0;
    while (my $row_ref = $sth->fetchrow_hashref())
    {
        #say %$row_ref;
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

$sqlserver->disconnect();
$redis->disconnect();
