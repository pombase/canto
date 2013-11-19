package Canto::View::JSON;

use Moose;
use namespace::autoclean;

extends 'Catalyst::View::JSON';

=head1 NAME

Canto::View::JSON - Catalyst View for JSON

=head1 DESCRIPTION

Catalyst View.

=head1 AUTHOR

Kim Rutherford,,,

=head1 LICENSE

Canto is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

=cut

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

