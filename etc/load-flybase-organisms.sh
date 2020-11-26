#!/bin/sh -

# download the species and taxon file and add all species that have a taxon ID

curl ftp://ftp.flybase.net/releases/current/precomputed_files/species/organism_list_fb_2020_05.tsv.gz |
    gzip -d |
    perl -ne '
my ($genus, $species, $abbreviation, $common_name, $taxonid)  = split /\t/, $_;
print qq|perl ./script/canto_add.pl --organism "$genus $species" "$taxonid" "$common_name"\n| if $taxonid =~ /^\d+$/;
' |
    bash
