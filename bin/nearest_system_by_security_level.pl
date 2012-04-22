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

    my @candidates = ( [ $current_system_id ] );
    my @results;

    my $depth = 1;
    my $finished = 0;
    my %systems_seen = ( $current_system_id => 1 );
    while (!$finished)
    {
        for (my $i = 0; $i < scalar(@candidates); ++$i)
        {
            my $candidate_ref = $candidates[$i];
            if (scalar(@$candidate_ref) == $depth)
            {
                splice(@candidates, $i--, 1);
                my $system_id = $candidate_ref->[$depth - 1];
                my $sec = get_sec($system_id);

                #my $system_name = get_system_name($system_id);
                #say " % Examining $system_name\[" . ($sec / 10) . ']';

                if ($depth > 1 && $sec == $desired_sec)
                {
                    push(@results, $candidate_ref);
                    $finished = 1;
                }
                else
                {
                    my @new_candidates;
                    push(@new_candidates, map
                    {
                        [ @$candidate_ref, $_ ]
                    } @{get_gates($system_id)});

                    # Don't duplicate systems.
                    for (my $j = 0; $j < scalar(@new_candidates); ++$j)
                    {
                        my $new_system_id = $new_candidates[$j]->[$depth];
                        if ($systems_seen{$new_system_id})
                        {
                            splice(@new_candidates, $j--, 1);
                        }
                        else
                        {
                            $systems_seen{$new_system_id} = 1;
                        }
                    }

                    push(@candidates, @new_candidates);
                }
            }
        }

        ++$depth;
    }

    return \@results;
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

my $results_ref = scan($current_system_id, $desired_sec);

for my $result_ref (@$results_ref)
{
    say join(q{ -> }, map
    {
        my $system_name = get_system_name($_);
        my $sec = get_sec($_);
        if ($sec < 10)
        {
            $sec =~ s/(.)$/0\.$1/;
        }
        else
        {
            $sec =~ s/(.)$/\.$1/;
        }
        "${system_name}[$sec]"
    } @$result_ref);
}
