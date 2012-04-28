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
}

use constant BASE => 'eve';
use constant ETL =>
[
    'type' =>
    {
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
        'changeOfDuplicating' => 'chance_of_duplicating',
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

$sqlserver->disconnect();
$redis->disconnect();
