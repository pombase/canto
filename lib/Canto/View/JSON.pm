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

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

