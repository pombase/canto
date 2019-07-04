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

use Canto::Curs::AlleleManager;
use Canto::Curs::GenotypeManager;

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

    # code removed due the person table not having an orcid coulm
    #Canto::Track::update_all_statuses($config);
  },

  14 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

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

    $load_util->get_cvterm(cv_name => 'Canto cursprop types',
                           term_name => 'needs_approval_timestamp',
                           ontologyid => 'Canto:needs_approval_timestamp');

    Canto::Track::update_all_statuses($config);
  },

  15 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("ALTER TABLE genotype ADD COLUMN strain TEXT;");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);

  },

  16 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $dbh = $track_schema->storage()->dbh();

    $dbh->do("CREATE TABLE strains (
       organism_id integer NOT NULL REFERENCES organism (organism_id),
       strain_name text NOT NULL);");
  },

  17 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("ALTER TABLE organism ADD COLUMN pathogen_or_host TEXT default 'unknown' NOT NULL;");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  18 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;
      my $curs_key = $curs->curs_key();

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");
      $curs_dbh->do("CREATE TABLE organism_temp(organism_id, taxonid)");
      $curs_dbh->do("INSERT INTO organism_temp SELECT organism_id, taxonid FROM organism");
      $curs_dbh->do("DROP TABLE organism");
      $curs_dbh->do("ALTER TABLE organism_temp RENAME TO organism");
      $curs_dbh->do("PRAGMA foreign_keys = ON");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  19 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $dbh = $track_schema->storage()->dbh();

    $dbh->do("PRAGMA foreign_keys = OFF");
    $dbh->do("DROP TABLE strains");
    $dbh->do("CREATE TABLE strain (
       organism_id integer NOT NULL REFERENCES organism (organism_id),
       strain_name text NOT NULL);
      ");
  },

  20 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;
      my $curs_key = $curs->curs_key();

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");
      $curs_dbh->do("CREATE TABLE organism_temp(organism_id INTEGER PRIMARY KEY, taxonid INTEGER NOT NULL)");
      $curs_dbh->do("INSERT INTO organism_temp SELECT organism_id, taxonid FROM organism");
      $curs_dbh->do("DROP TABLE organism");
      $curs_dbh->do("ALTER TABLE organism_temp RENAME TO organism");
      $curs_dbh->do("PRAGMA foreign_keys = ON");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  21 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;
      my $curs_key = $curs->curs_key();

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("
CREATE TABLE metagenotype (
       metagenotype_id integer PRIMARY KEY AUTOINCREMENT,
       identifier text UNIQUE NOT NULL,
       pathogen_genotype_id integer NOT NULL REFERENCES genotype(genotype_id),
       host_genotype_id integer NOT NULL REFERENCES genotype(genotype_id)
);");

      $curs_dbh->do("
CREATE TABLE metagenotype_annotation (
       metagenotype_annotation_id integer PRIMARY KEY,
       metagenotype integer REFERENCES metagenotype(metagenotype_id),
       annotation integer REFERENCES annotation(annotation_id)
);
");

      $curs_dbh->do("
ALTER TABLE genotype ADD COLUMN organism_id integer REFERENCES organism(organism_id);");

      $curs_dbh->do("
UPDATE genotype SET organism_id =
   (SELECT gene.organism FROM gene
      JOIN allele ON allele.gene = gene.gene_id
      JOIN allele_genotype on allele.allele_id = allele_genotype.allele
     WHERE allele_genotype.genotype = genotype.genotype_id limit 1);
")
    };


    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  22 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    $dbh->do("PRAGMA foreign_keys = OFF");
    $dbh->do("ALTER TABLE organism RENAME TO organism_temp;");
    $dbh->do("CREATE TABLE organism (
       organism_id integer NOT NULL PRIMARY KEY,
       abbreviation varchar(255) null,
       scientific_name varchar(255) NOT NULL,
       common_name varchar(255) null,
       comment text null);
    ");
    $dbh->do(qq{
       INSERT INTO organism(organism_id, abbreviation, scientific_name, common_name, comment)
       SELECT organism_id, abbreviation, genus || " " || species, common_name, comment FROM organism_temp;
    });
    $dbh->do("DROP TABLE organism_temp;");
    $dbh->do("PRAGMA foreign_keys = ON");
  },

  23 => sub {
    my $config = shift;
    my $track_schema = shift;
    my $load_util = shift;

    my $dbh = $track_schema->storage()->dbh();

    $dbh->do("PRAGMA foreign_keys = OFF");
    $dbh->do(<<"EOF");
CREATE TABLE strain_temp (
       strain_id integer NOT NULL PRIMARY KEY,
       organism_id integer NOT NULL REFERENCES organism (organism_id),
       strain_name text NOT NULL
);
EOF

    $dbh->do("INSERT INTO strain_temp(organism_id, strain_name) " .
             "SELECT organism_id, strain_name FROM strain");

    $dbh->do("DROP TABLE strain");
    $dbh->do("ALTER TABLE strain_temp RENAME TO strain");

    $dbh->do("CREATE INDEX strain_organism_index_idx ON strain(organism_id)");

    $dbh->do("PRAGMA foreign_keys = ON");
  },

  24 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");

      $curs_dbh->do("DROP TABLE if exists genotype_temp ");

      $curs_dbh->do("CREATE TABLE strain (
       strain_id integer PRIMARY KEY AUTOINCREMENT,
       organism_id integer REFERENCES organism(organism_id),
       -- ID of the strain in the TrackDB:
       track_strain_id integer UNIQUE,
       strain_name text
)");

      $curs_dbh->do("CREATE TABLE genotype_temp(
         genotype_id integer PRIMARY KEY AUTOINCREMENT,
         identifier text UNIQUE NOT NULL,
         background text,
         strain_id integer REFERENCES strain(strain_id),
         organism_id integer REFERENCES organism(organism_id),
         name text UNIQUE
)");
      $curs_dbh->do("INSERT INTO genotype_temp
         SELECT genotype_id, identifier, background, null, organism_id, name
         FROM genotype");

      $curs_dbh->do("DROP TABLE genotype");

      $curs_dbh->do("ALTER TABLE genotype_temp RENAME TO genotype");

      $curs_dbh->do("PRAGMA foreign_keys = ON");
    };


    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  25 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");

      $curs_dbh->do("DROP TABLE if exists allele_temp");

      $curs_dbh->do("CREATE TABLE allele_temp (
       allele_id integer PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       type text NOT NULL,  -- 'deletion', 'partial deletion, nucleotide' etc.
       description text,
       expression text,
       name text,
       gene integer REFERENCES gene(gene_id))");

      $curs_dbh->do("INSERT INTO allele_temp
         SELECT allele_id, primary_identifier, type, description,
                expression, name, gene
         FROM allele");

      $curs_dbh->do("DROP TABLE allele");

      $curs_dbh->do("ALTER TABLE allele_temp RENAME TO allele");

      $curs_dbh->do("PRAGMA foreign_keys = ON");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  26 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");

      $curs_dbh->do("DROP TABLE if exists genotype_temp");

      $curs_dbh->do("CREATE TABLE genotype_temp (
       genotype_id integer PRIMARY KEY AUTOINCREMENT,
       identifier text UNIQUE NOT NULL,
       background text,
       comment text,
       strain_id integer REFERENCES strain(strain_id),
       organism_id integer REFERENCES organism(organism_id),
       name text UNIQUE)");

      $curs_dbh->do("INSERT INTO genotype_temp
         SELECT genotype_id, identifier, background, null, strain_id, organism_id, name
         FROM genotype");

      $curs_dbh->do("DROP TABLE genotype");

      $curs_dbh->do("ALTER TABLE genotype_temp RENAME TO genotype");

      $curs_dbh->do("PRAGMA foreign_keys = ON");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  27 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("
CREATE TABLE allelesynonym (
       allelesynonym integer PRIMARY KEY,
       allele integer REFERENCES allele(allele_id),
       edit_status text NOT NULL, -- 'existing', 'new', 'deleted'
       synonym text NOT NULL
);
      ");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  28 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("
CREATE TABLE diploid (
       diploid_id integer PRIMARY KEY,
       name text UNIQUE
);
       ");

      $curs_dbh->do("ALTER TABLE allele_genotype ADD COLUMN diploid integer REFERENCES diploid(diploid_id);");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  29 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("ALTER TABLE allele ADD COLUMN comment text;");
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
  },

  30 => sub {
    my $config = shift;
    my $track_schema = shift;

    my $dbh = $track_schema->storage()->dbh();

    my $update_proc = sub {
      my $curs = shift;
      my $curs_schema = shift;
      my $curs_key = $curs->curs_key();

      my $curs_dbh = $curs_schema->storage()->dbh();

      $curs_dbh->do("PRAGMA foreign_keys = OFF");

      $curs_dbh->do("DROP TABLE if exists metagenotype_temp");

      $curs_dbh->do("
CREATE TABLE metagenotype_temp (
       metagenotype_id integer PRIMARY KEY AUTOINCREMENT,
       identifier text UNIQUE NOT NULL,
       type TEXT NOT NULL CHECK(type = 'pathogen-host' OR type = 'interaction'),
       first_genotype_id integer NOT NULL REFERENCES genotype(genotype_id),
       second_genotype_id integer NOT NULL REFERENCES genotype(genotype_id)
);
      ");

      $curs_dbh->do("INSERT INTO metagenotype_temp(metagenotype_id, identifier, first_genotype_id, second_genotype_id, type)
         SELECT metagenotype_id, identifier, pathogen_genotype_id, host_genotype_id, 'pathogen-host'
         FROM metagenotype
      ");

      $curs_dbh->do("DROP TABLE metagenotype");

      $curs_dbh->do("ALTER TABLE metagenotype_temp RENAME TO metagenotype");

      my $annotation_rs = $curs_schema->resultset('Annotation');

      $curs_dbh->do("PRAGMA foreign_keys = ON");

      my $genotype_manager = Canto::Curs::GenotypeManager->new(config => $config,
                                                               curs_schema => $curs_schema);

      my @old_interaction_annotations = ();

      while (defined (my $old_annotation = $annotation_rs->next())) {
        if ($old_annotation->type() eq 'physical_interaction' ||
            $old_annotation->type() eq 'genetic_interaction') {
          push @old_interaction_annotations, $old_annotation;

          my $data = $old_annotation->data();
          my $interacting_genes = delete $data->{interacting_genes};

          map {
            my @a_genes = $old_annotation->genes();

            if (@a_genes > 1) {
              die "can't upgrade $curs_key, interaction annotation has more than 1 gene";
            }

            if (@a_genes == 0) {
              die "can't upgrade $curs_key, interaction annotation has no genes";
            }

            my $gene_a = $a_genes[0];

            my $json_allele_a = {
              type => 'unspecified',
              gene_id => $gene_a->gene_id(),
            };

            my $taxonid = $gene_a->organism()->taxonid();

            my $genotype_a =
              $genotype_manager->make_genotype(undef, undef, [$json_allele_a], $taxonid,
                                               undef, undef, undef);

            my $gene_b_primary_identifier = $_->{primary_identifier};
            my $gene_b = $curs_schema->resultset('Gene')
              ->find({
                primary_identifier => $gene_b_primary_identifier,
              }, {
                prefetch => 'organism',
              });

            my $json_allele_b = {
              type => 'unspecified',
              gene_id => $gene_b->gene_id(),
            };

            my $taxonid_b = $gene_b->organism()->taxonid();

            my $genotype_b =
              $genotype_manager->make_genotype(undef, undef, [$json_allele_b], $taxonid_b,
                                               undef, undef, undef);

            if ($data->{evidence_code} eq 'Synthetic Lethality') {
              $data->{term_ontid} = 'FYPO:0002059';
            }

            my $annotation =
              $curs_schema->create_with_type('Annotation',
                                             {
                                               status => $old_annotation->status(),
                                               pub => $old_annotation->pub(),
                                               type => $old_annotation->type(),
                                               creation_date => $old_annotation->creation_date(),
                                               data => $data,
                                             });

            my $metagenotype =
              $genotype_manager->make_metagenotype(interactor_a => $genotype_a,
                                                   interactor_b => $genotype_b);

            $annotation->set_metagenotypes($metagenotype);
          } @$interacting_genes;
        }
      }

      map {
        my $old_annotation = $_;

        $old_annotation->delete();
      } @old_interaction_annotations;
    };

    Canto::Track::curs_map($config, $track_schema, $update_proc);
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
