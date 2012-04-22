#!/usr/bin/perl

use common::sense;

use Redis;

sub usage
{
    my ($bin) = @_;

    say "Usage: $bin <current_system_name> <desired_security_level>";
    exit -1;
}

sub fatal
{
    say "FATAL: ", @_;
    exit 1;
}

my $redis = Redis->new(encoding => undef) or die $!;
sub get_sec
{
    my ($system_id) = @_;

    my $real_sec = $redis->get("eve.system.$system_id.sec");

    # Turn security status into an integer; e.g. 0.41234 -> 4. 
    return int($real_sec * 10 + 0.5);
}

sub get_system_name
{
    my ($system_id) = @_;

    return $redis->get("eve.system.$system_id.name");
}

sub get_gates
{
    my ($system_id) = @_;

    my $num_gates = $redis->llen("eve.system.$system_id.gates");

    my @gates;
    for (my $i = 0; $i < $num_gates; ++$i)
    {
        push(@gates, $redis->lindex("eve.system.$system_id.gates", $i));
    }

    return \@gates;
}

sub scan
{
    my ($current_system_id, $desired_sec) = @_;

    my %seen = ( $current_system_id => 1 );

    my @queue = ($current_system_id);

    # Breadth-first search.
    while (scalar(@queue) > 0)
    {
        my $system_id = shift(@queue);
        my $system_name = get_system_name($system_id);
        my $sec = get_sec($system_id);
        my $name_sec = "${system_name}[$sec]";
        say "Processing: $name_sec";

        if ($sec eq $desired_sec)
        {
            return $name_sec;
        }

        my $gates_ref = get_gates($system_id);
        for (my $i = 0; $i < scalar(@$gates_ref); ++$i)
        {
            my $gate_system_id = $gates_ref->[$i];
            push(@queue, $gate_system_id) unless $seen{$gate_system_id};
            $seen{$gate_system_id} = 1;
        }
    }
}

if (!$ARGV[0] || !$ARGV[1])
{
    usage($0);
}

my $current_system = $ARGV[0];
my $desired_sec = $ARGV[1] * 10;

my $redis = Redis->new(encoding => undef);

my $current_system_id = $redis->get("eve.system.by_name.$current_system.id");
if (!$current_system_id)
{
    fatal("Unknown system: $current_system");
}

say scan($current_system_id, $desired_sec);
