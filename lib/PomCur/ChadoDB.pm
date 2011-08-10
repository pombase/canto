package PomCur::ChadoDB;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use Moose;
use namespace::autoclean;
extends 'PomCur::DB';

__PACKAGE__->load_classes;


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1OAFzIe/alUSreHpX9xsaw


__PACKAGE__->initialise();

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

our %cache = ();

sub get_cvterm
{
  my $self = shift;
  my $cv_name = shift;
  my $cvterm_name = shift;

  my $key = "cvterm:$cv_name:$cvterm_name";

  if (exists $cache{$key}) {
    return $cache{$key};
  } else {
    my $cv = $self->find_with_type('Cv', { name => $cv_name });
    my $cvterm = $self->find_with_type('Cvterm', { name => $cvterm_name,
                                                   cv_id => $cv->cv_id() });
    $cache{$key} = $cvterm;
  }
}

1;
