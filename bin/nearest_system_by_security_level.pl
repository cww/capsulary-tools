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

use Log::Log4perl qw(:easy);
use Redis;

use Capsulary::DB::Redis;

my $redis;

BEGIN
{
    Log::Log4perl->easy_init($INFO);
}

sub usage
{
    my ($bin) = @_;

    say "Usage: $bin <current_system_name> <desired_security_level>";
    exit -1;
}

sub fatal
{
    FATAL join(q{ }, @_);
    exit 1;
}

sub get_sec
{
    my ($system_id) = @_;

    my $real_sec =
        $redis->get_handle()->get("eve.solar_system.$system_id.security");

    # Turn security status into an integer; e.g. 0.41234 -> 4. 
    return int($real_sec * 10 + 0.5);
}

sub get_system_name
{
    my ($system_id) = @_;

    return $redis->get_handle()->get("eve.solar_system.$system_id.name");
}

sub get_gates
{
    my ($system_id) = @_;

    my $rh = $redis->get_handle();

    my @gate_map_ids =
    $rh->smembers("eve.solar_system_jump.by_from_solar_system_id.$system_id");

    my @gates = map
    {
        $rh->get("eve.solar_system_jump.$_.to_solar_system_id");
    } @gate_map_ids;

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

usage($0) unless defined($ARGV[0]) && defined($ARGV[1]);

my $current_system = $ARGV[0];
my $desired_sec = $ARGV[1];

$redis = Capsulary::DB::Redis->new();
$redis->connect();

my $rh = $redis->get_handle();

my @system_backrefs = $rh->smembers("eve.solar_system.by_name.$current_system");
my $current_system_id = $system_backrefs[0];
if (!$current_system_id)
{
    fatal("Unknown system: $current_system");
}

if ($desired_sec <= -1.0 || $desired_sec > 1.0)
{
    fatal("Desired security status out of range (-1.0,1.0]: $desired_sec");
}

# Playing with integers is easier than playing with floats.
$desired_sec = int($desired_sec * 10);

my $results_ref = scan($current_system_id, $desired_sec);

for my $result_ref (@$results_ref)
{
    # Format the output: System1[sec] -> System2[sec] -> System3[sec] -> ...
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
