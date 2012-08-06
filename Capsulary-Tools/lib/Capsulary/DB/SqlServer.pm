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
