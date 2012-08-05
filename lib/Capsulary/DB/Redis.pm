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
package Capsulary::DB::Redis;

use common::sense;

use Carp;
use Redis;

use constant DEFAULT_REDIS_HOST => 'localhost';
use constant DEFAULT_REDIS_PORT => 6379;

sub get_default_redis_host
{
    return DEFAULT_REDIS_HOST;
}

sub get_default_redis_port
{
    return DEFAULT_REDIS_PORT;
}

sub new
{
    my ($class, $args_ref) = @_;

    my %self =
    (
        host => $args_ref->{host} // DEFAULT_REDIS_HOST,
        port => $args_ref->{port} // DEFAULT_REDIS_PORT,
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
    my ($self) = @_;
    return $self->{dbh};
}

sub disconnect
{
    my ($self) = @_;
    $self->{dbh}->quit() if $self->{dbh};
}

1;
