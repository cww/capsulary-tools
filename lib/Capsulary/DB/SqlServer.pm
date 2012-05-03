package Capsulary::DB::SqlServer;

use common::sense;

use Carp;
use DBI;

sub new
{
    my ($class, $args_ref) = @_;

    croak 'Must specify DSN'      unless $args_ref->{dsn};
    croak 'Must specify username' unless $args_ref->{username};
    croak 'Must specify password' unless $args_ref->{password};

    my %self =
    (
        dsn      => $args_ref->{dsn},
        username => $args_ref->{username},
        password => $args_ref->{password},
    );

    return bless(\%self, $class);
}

sub connect
{
    my ($self) = @_;
    $self->{dbh} = DBI->connect
    (
        "dbi:ODBC:dsn=$self->{dsn}",
        $self->{username},
        $self->{password},
        { RaiseError => 1 },
    ) or croak $!;
}

sub get_handle
{
    my ($self) = @_;
    return $self->{dbh};
}

sub disconnect
{
    my ($self) = @_;
    $self->{dbh}->disconnect() if $self->{dbh};
}

1;
