#!/bin/sh

go_ext_url="http://www.geneontology.org/ontology/obo_format_1_2/gene_ontology_ext.obo"
phenotype_file="../sources/phenotype_ontology/fypo.obo"
psi_mod_file="../sources/PSI-MOD.obo"
ro_file="etc/ro.obo"

./script/pomcur_load.pl --ontology $ro_file --ontology $go_ext_url \
                        --ontology $psi_mod_file --ontology $phenotype_file

./script/pomcur_load.pl --genes ../sources/genes_and_products.txt --for-taxon=4896
