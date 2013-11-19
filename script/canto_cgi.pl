#!/usr/bin/env perl

BEGIN {
  $ENV{CANTO_CONFIG_LOCAL_SUFFIX} ||= 'deploy';
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('Canto', 'CGI');

1;

=head1 NAME

canto_cgi.pl - Catalyst CGI

=head1 SYNOPSIS

See L<Catalyst::Manual>

=head1 DESCRIPTION

Run a Catalyst application as a cgi script.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut

