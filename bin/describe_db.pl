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

use Capsulary::DB::Redis;

my $db = Capsulary::DB::Redis->new({ host => 'localhost', port => 9160 });
my $redis = $db->connect();

my @keys = $redis->keys('*');
$db->disconnect();

my %seen;
for my $key (@keys)
{
    my @key_parts = split(/\./, $key);

    for (my $i = 0; $i < @key_parts; ++$i)
    {
        # Assume all numbered parts are object IDs and therefore can be
        # treated the same.
        $key_parts[$i] = '---' if $key_parts[$i] =~ /^\d+$/;

        my $seen_key = join(q{.}, @key_parts[0 .. $i]);
        $seen{$seen_key} = 1;

        last if $key_parts[$i] =~ /^by_/;
    }
}

say join("\n", sort { $a cmp $b } keys %seen);
