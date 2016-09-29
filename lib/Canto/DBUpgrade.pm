package Canto::DBUpgrade;

=head1 NAME

Canto::DBUpgrade - Code for upgrading Track and Curs databases

=head1 SYNOPSIS

=head1 AUTHOR

Kim Rutherford C<< <kmr44@cam.ac.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<kmr44@cam.ac.uk>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Canto::DBUpgrade

=over 4

=back

=head1 COPYRIGHT & LICENSE

Copyright 2013 Kim Rutherford, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 FUNCTIONS

=cut

use Moose;
use Try::Tiny;

use Canto::Track;
use Canto::ExtensionUtil;
use Canto::Track;

has config => (is => 'ro', required => 1);

my %procs = (
  10 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $adaptor = Canto::Track::get_adaptor($config, 'gene');

    my $cvprop_type_cv =
      $load_util->find_or_create_cv('cvprop_type');

    $load_util->get_cvterm(cv => $cvprop_type_cv,
                           term_name => 'cv_date',
                           ontologyid => 'Canto:cv_date');
    $load_util->get_cvterm(cv => $cvprop_type_cv,
                           term_name => 'cv_term_count',
                           ontologyid => 'Canto:cv_term_count');

    $load_util->get_cvterm(cv_name => 'cvterm_property_type',
                           term_name => 'canto_subset',
                           ontologyid => 'Canto:canto_subset');

    my $dbh = $track_schema->storage()->dbh();
    $dbh->do("CREATE INDEX cvtermprop_value_idx ON cvtermprop(value)");

    if ($track_schema->resultset('Cv')->search({ name => 'canto_core' })->count() == 0) {
      $dbh->do("insert into cv(name) values('canto_core')");
    }

    $load_util->get_cvterm(cv_name => 'canto_core',
                           term_name => 'is_a',
                           ontologyid => 'Canto:is_a');

    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $rs = $curs_schema->resultset('Annotation');

      for my $an ($rs->all()) {
        my $data = $an->data();

        my $extension_string = delete $data->{annotation_extension};

        if ($extension_string) {
          try {
            my @extension = Canto::ExtensionUtil::parse_extension($extension_string);

            map {
              my $orPart = $_;
              map {
                my $andPart = $_;
                my $range_value = $andPart->{rangeValue};
                if ($range_value =~ /^(?:GO|FYPO|SO|FYPO_EXT|PATO|PBHQ):\d+/) {
                  my @dbxrefs = $load_util->find_dbxref($range_value);
                  if (@dbxrefs == 1) {
                    my @cvterms = $dbxrefs[0]->cvterms();
                    if (@cvterms == 1) {
                      $andPart->{rangeDisplayName} = $cvterms[0]->name();
                      $andPart->{rangeType} = 'Ontology';
                    }
                  }
                } else {
                  if ($range_value =~ /^PomBase:(\S+)/) {
                    my $result = $adaptor->lookup([$1]);
                    my $found = $result->{found};

                    if ($found && @$found == 1 && $found->[0]->{primary_name}) {
                      $andPart->{rangeDisplayName} = $found->[0]->{primary_name};
                    }

                    $andPart->{rangeType} = 'Gene';
                  } else {
                    if ($andPart->{relation} eq 'has_penetrance') {
                      $andPart->{rangeType} = '%';
                      $andPart->{rangeValue} =~ s/\s*\%\s*$//;
                    } else {
                      $andPart->{rangeType} = 'Text';
                    }
                  }
                }
              } @$orPart;
            } @extension;

            $data->{extension} = \@extension;
          } catch {
            warn qq(failed to store extension in $curs_key: $_);
          };
        }

        $an->data($data);
        $an->update();
      }
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);

  },

  11 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("update allele set expression = 'Wild Type product level' where expression = 'Endogenous';");
      $curs_dbh->do("update allele set expression = 'Not assayed' where expression = 'Not specified'");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  12 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $update_proc = sub {
      my $curs = shift;
      my $curs_key = $curs->curs_key();
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("update allele set expression = 'Wild type product level' where expression = 'Wild Type product level';");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  13 => sub {
    my $config = shift;

    Canto::Track::update_all_statuses($config);
  },

  14 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    $dbh->do("PRAGMA foreign_keys = OFF");

    $dbh->do(<<"EOF");
CREATE TABLE person_temp (
  person_id integer NOT NULL PRIMARY KEY,
  name text NOT NULL,
  email_address text NOT NULL UNIQUE,
  orcid text UNIQUE,
  role integer REFERENCES cvterm(cvterm_id) NOT NULL,
  lab INTEGER REFERENCES lab (lab_id),
  session_data text,
  password text,
  added_date timestamp,
  known_as TEXT);
EOF

    $dbh->do("INSERT INTO person_temp(person_id, name, email_address, known_as, role, lab, session_data, password, added_date) " .
             "SELECT person_id, name, email_address, known_as, role, lab, session_data, password, added_date FROM person");

    $dbh->do("DROP TABLE person");
    $dbh->do("ALTER TABLE person_temp RENAME TO person");

    $dbh->do("CREATE INDEX person_role_idx ON person(role)");

    $dbh->do("PRAGMA foreign_keys = ON");
  },
);

sub upgrade_to
{
  my $self = shift;
  my $version = shift;

  my $track_schema = Canto::TrackDB->new(config => $self->config());
  my $load_util = Canto::Track::LoadUtil->new(schema => $track_schema);

  if (exists $procs{$version}) {
    $procs{$version}->($self->config(), $track_schema, $load_util);
  } else {
    die "don't know how to upgrade to $version\n";
  }
}

1;
