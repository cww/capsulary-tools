package Capsulary::DB::Redis;

use Carp;
use Redis;

sub new
{
    my ($class, $args_ref) = @_;

    croak 'Must specify host' unless $args_ref->{host};
    croak 'Must specify port' unless $args_ref->{port};

    my %self =
    (
        host => $args_ref->{host},
        port => $args_ref->{port},
    );

    return bless(\%self, $class);
}

sub connect
{
    my ($self) = @_;
    $self->{dbh} = Redis->new(encoding => undef) or croak $!;
}

sub get_handle
{
    return $self->{dbh};
}

sub disconnect
{
    $self->{dbh}->disconnect() if $self->{dbh};
}

1;
