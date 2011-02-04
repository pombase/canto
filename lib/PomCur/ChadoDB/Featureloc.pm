package PomCur::ChadoDB::Featureloc;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
extends 'DBIx::Class::Core';


=head1 NAME

PomCur::ChadoDB::Featureloc

=head1 DESCRIPTION

The location of a feature relative to
another feature. Important: interbase coordinates are used. This is
vital as it allows us to represent zero-length features e.g. splice
sites, insertion points without an awkward fuzzy system. Features
typically have exactly ONE location, but this need not be the
case. Some features may not be localized (e.g. a gene that has been
characterized genetically but no sequence or molecular information is
available). Note on multiple locations: Each feature can have 0 or
more locations. Multiple locations do NOT indicate non-contiguous
locations (if a feature such as a transcript has a non-contiguous
location, then the subfeatures such as exons should always be
manifested). Instead, multiple featurelocs for a feature designate
alternate locations or grouped locations; for instance, a feature
designating a blast hit or hsp will have two locations, one on the
query feature, one on the subject feature. Features representing
sequence variation could have alternate locations instantiated on a
feature on the mutant strain. The column:rank is used to
differentiate these different locations. Reflexive locations should
never be stored - this is for -proper- (i.e. non-self) locations only; nothing should be located relative to itself.

=cut

__PACKAGE__->table("featureloc");

=head1 ACCESSORS

=head2 featureloc_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'featureloc_featureloc_id_seq'

=head2 feature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

The feature that is being located. Any feature can have zero or more featurelocs.

=head2 srcfeature_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

The source feature which this location is relative to. Every location is relative to another feature (however, this column is nullable, because the srcfeature may not be known). All locations are -proper- that is, nothing should be located relative to itself. No cycles are allowed in the featureloc graph.

=head2 fmin

  data_type: 'integer'
  is_nullable: 1

The leftmost/minimal boundary in the linear range represented by the featureloc. Sometimes (e.g. in Bioperl) this is called -start- although this is confusing because it does not necessarily represent the 5-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. To convert this to the leftmost position in a base-oriented system (eg GFF, Bioperl), add 1 to fmin.

=head2 is_fmin_partial

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

This is typically
false, but may be true if the value for column:fmin is inaccurate or
the leftmost part of the range is unknown/unbounded.

=head2 fmax

  data_type: 'integer'
  is_nullable: 1

The rightmost/maximal boundary in the linear range represented by the featureloc. Sometimes (e.g. in bioperl) this is called -end- although this is confusing because it does not necessarily represent the 3-prime coordinate. Important: This is space-based (interbase) coordinates, counting from zero. No conversion is required to go from fmax to the rightmost coordinate in a base-oriented system that counts from 1 (e.g. GFF, Bioperl).

=head2 is_fmax_partial

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

This is typically
false, but may be true if the value for column:fmax is inaccurate or
the rightmost part of the range is unknown/unbounded.

=head2 strand

  data_type: 'smallint'
  is_nullable: 1

The orientation/directionality of the
location. Should be 0, -1 or +1.

=head2 phase

  data_type: 'integer'
  is_nullable: 1

Phase of translation with
respect to srcfeature_id.
Values are 0, 1, 2. It may not be possible to manifest this column for
some features such as exons, because the phase is dependant on the
spliceform (the same exon can appear in multiple spliceforms). This column is mostly useful for predicted exons and CDSs.

=head2 residue_info

  data_type: 'text'
  is_nullable: 1

Alternative residues,
when these differ from feature.residues. For instance, a SNP feature
located on a wild and mutant protein would have different alternative residues.
for alignment/similarity features, the alternative residues is used to
represent the alignment string (CIGAR format). Note on variation
features; even if we do not want to instantiate a mutant
chromosome/contig feature, we can still represent a SNP etc with 2
locations, one (rank 0) on the genome, the other (rank 1) would have
most fields null, except for alternative residues.

=head2 locgroup

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

This is used to manifest redundant,
derivable extra locations for a feature. The default locgroup=0 is
used for the DIRECT location of a feature. Important: most Chado users may
never use featurelocs WITH logroup > 0. Transitively derived locations
are indicated with locgroup > 0. For example, the position of an exon on
a BAC and in global chromosome coordinates. This column is used to
differentiate these groupings of locations. The default locgroup 0
is used for the main or primary location, from which the others can be
derived via coordinate transformations. Another example of redundant
locations is storing ORF coordinates relative to both transcript and
genome. Redundant locations open the possibility of the database
getting into inconsistent states; this schema gives us the flexibility
of both warehouse instantiations with redundant locations (easier for
querying) and management instantiations with no redundant
locations. An example of using both locgroup and rank: imagine a
feature indicating a conserved region between the chromosomes of two
different species. We may want to keep redundant locations on both
contigs and chromosomes. We would thus have 4 locations for the single
conserved region feature - two distinct locgroups (contig level and
chromosome level) and two distinct ranks (for the two species).

=head2 rank

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

Used when a feature has >1
location, otherwise the default rank 0 is used. Some features (e.g.
blast hits and HSPs) have two locations - one on the query and one on
the subject. Rank is used to differentiate these. Rank=0 is always
used for the query, Rank=1 for the subject. For multiple alignments,
assignment of rank is arbitrary. Rank is also used for
sequence_variant features, such as SNPs. Rank=0 indicates the wildtype
(or baseline) feature, Rank=1 indicates the mutant (or compared) feature.

=cut

__PACKAGE__->add_columns(
  "featureloc_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "featureloc_featureloc_id_seq",
  },
  "feature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "srcfeature_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "fmin",
  { data_type => "integer", is_nullable => 1 },
  "is_fmin_partial",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "fmax",
  { data_type => "integer", is_nullable => 1 },
  "is_fmax_partial",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "strand",
  { data_type => "smallint", is_nullable => 1 },
  "phase",
  { data_type => "integer", is_nullable => 1 },
  "residue_info",
  { data_type => "text", is_nullable => 1 },
  "locgroup",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "rank",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("featureloc_id");
__PACKAGE__->add_unique_constraint("featureloc_c1", ["feature_id", "locgroup", "rank"]);

=head1 RELATIONS

=head2 feature

Type: belongs_to

Related object: L<PomCur::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "feature",
  "PomCur::ChadoDB::Feature",
  { feature_id => "feature_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 srcfeature

Type: belongs_to

Related object: L<PomCur::ChadoDB::Feature>

=cut

__PACKAGE__->belongs_to(
  "srcfeature",
  "PomCur::ChadoDB::Feature",
  { feature_id => "srcfeature_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 featureloc_pubs

Type: has_many

Related object: L<PomCur::ChadoDB::FeaturelocPub>

=cut

__PACKAGE__->has_many(
  "featureloc_pubs",
  "PomCur::ChadoDB::FeaturelocPub",
  { "foreign.featureloc_id" => "self.featureloc_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07006 @ 2011-02-04 16:45:42
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:koqXezW0S+2BoP8hmN4uzw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
