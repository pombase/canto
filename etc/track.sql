PRAGMA foreign_keys=ON;

CREATE TABLE pub (
       pub_id integer NOT NULL PRIMARY KEY,
       uniquename text UNIQUE NOT NULL,
       type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       corresponding_author integer REFERENCES person (person_id),
       title text,
       abstract text,
       authors text,
       affiliation text,
       citation text,
       publication_date text,
       pubmed_type integer REFERENCES cvterm (cvterm_id),
       triage_status_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       load_type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       curation_priority_id integer REFERENCES cvterm (cvterm_id),
       community_curatable boolean DEFAULT false,
       added_date timestamp
);
CREATE INDEX pub_triage_status_idx ON pub(triage_status_id);

CREATE INDEX pub_type_id_idx ON pub(type_id);
CREATE INDEX pub_pubmed_type_idx ON pub(pubmed_type);
CREATE INDEX pub_triage_status_id_idx ON pub(triage_status_id);
CREATE INDEX pub_load_type_id_idx ON pub(load_type_id);
CREATE INDEX pub_curation_priority_id_idx ON pub(curation_priority_id);

CREATE TABLE pubprop (
       pubprop_id integer NOT NULL PRIMARY KEY,
       pub_id integer NOT NULL REFERENCES pub (pub_id),
       type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       value text NOT NULL,
       rank integer DEFAULT 0 NOT NULL
);

CREATE INDEX pubprop_pub_id_idx ON pubprop(pub_id);
CREATE INDEX pubprop_type_id_idx ON pubprop(type_id);

CREATE TABLE pub_curation_status (
       pub_curation_status_id integer NOT NULL PRIMARY KEY,
       pub_id integer NOT NULL REFERENCES pub (pub_id),
       annotation_type text,
       status_id integer NOT NULL REFERENCES cvterm (cvterm_id)
);

CREATE TABLE cv (
       cv_id integer NOT NULL PRIMARY KEY,
       name text NOT NULL,
       definition text
);


CREATE TABLE db (
       db_id integer NOT NULL PRIMARY KEY,
       name text NOT NULL,
       description text,
       urlprefix text,
       url text
);

CREATE TABLE dbxref (
       dbxref_id integer NOT NULL PRIMARY KEY,
       db_id integer NOT NULL REFERENCES db (db_id),
       accession text NOT NULL,
       version text NOT NULL DEFAULT '',
       description text
);
CREATE INDEX dbxref_idx1 ON dbxref (db_id);
CREATE INDEX dbxref_idx2 ON dbxref (accession);
CREATE INDEX dbxref_idx3 ON dbxref (version);
CREATE UNIQUE INDEX dbxref_db_accession_unique ON dbxref(accession, db_id);

CREATE TABLE cvterm (
       cvterm_id integer NOT NULL PRIMARY KEY,
       cv_id int NOT NULL references cv (cv_id),
       name text NOT NULL,
       dbxref_id integer NOT NULL REFERENCES dbxref (dbxref_id),
       definition text,
       is_obsolete integer DEFAULT 0 NOT NULL,
       is_relationshiptype integer DEFAULT 0 NOT NULL
);
CREATE INDEX cvterm_idx1 ON cvterm (cv_id);
CREATE INDEX cvterm_idx2 ON cvterm (name);
CREATE UNIQUE INDEX cvterm_name_cv_unique ON cvterm(name, cv_id);

CREATE TABLE cvtermsynonym (
       cvtermsynonym_id integer NOT NULL PRIMARY KEY,
       cvterm_id integer NOT NULL references cvterm (cvterm_id),
       synonym text NOT NULL,
       type_id integer references cvterm (cvterm_id)
);
CREATE INDEX cvtermsynonym_idx1 ON cvtermsynonym (cvterm_id);
CREATE INDEX cvtermsynonym_type_id_idx ON cvtermsynonym (type_id);

CREATE TABLE cvterm_relationship (
       cvterm_relationship_id integer NOT NULL PRIMARY KEY,
       type_id integer NOT NULL references cvterm (cvterm_id),
       subject_id integer NOT NULL references cvterm (cvterm_id),
       object_id integer NOT NULL references cvterm (cvterm_id)
);
CREATE INDEX cvterm_relationship_idx1 ON cvterm_relationship (type_id);
CREATE INDEX cvterm_relationship_idx2 ON cvterm_relationship (subject_id);
CREATE INDEX cvterm_relationship_idx3 ON cvterm_relationship (object_id);

CREATE TABLE cvtermprop (
       cvtermprop_id integer NOT NULL PRIMARY KEY,
       cvterm_id integer NOT NULL references cvterm (cvterm_id),
       type_id integer NOT NULL references cvterm (cvterm_id),
       value text DEFAULT '' NOT NULL,
       rank integer DEFAULT 0 NOT NULL
);
CREATE INDEX cvtermprop_idx1 ON cvtermprop (cvterm_id);
CREATE INDEX cvtermprop_idx2 ON cvtermprop (type_id);

CREATE TABLE cvterm_dbxref (
       cvterm_dbxref_id integer NOT NULL PRIMARY KEY,
       cvterm_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       dbxref_id integer NOT NULL REFERENCES dbxref (dbxref_id),
       is_for_definition integer DEFAULT 0 NOT NULL
);
CREATE UNIQUE INDEX cvterm_dbxref_c1 on cvterm_dbxref (cvterm_id, dbxref_id);
CREATE INDEX cvterm_dbxref_idx1 ON cvterm_dbxref (cvterm_id);
CREATE INDEX cvterm_dbxref_idx2 ON cvterm_dbxref (dbxref_id);

CREATE TABLE organism (
       organism_id integer NOT NULL PRIMARY KEY,
       abbreviation varchar(255) null,
       genus varchar(255) NOT NULL,
       species varchar(255) NOT NULL,
       common_name varchar(255) null,
       comment text null
);

CREATE INDEX organism_idx1 ON organism (organism_id);

CREATE TABLE organismprop (
       organismprop_id integer NOT NULL PRIMARY KEY,
       organism_id integer NOT NULL REFERENCES organism (organism_id),
       type_id integer NOT NULL REFERENCES cvterm (cvterm_id),
       value text,
       rank integer DEFAULT 0 NOT NULL
);

CREATE INDEX organismprop_idx1 ON organismprop (organism_id);
CREATE INDEX organismprop_idx2 ON organismprop (type_id);

CREATE TABLE pub_organism (
       pub_organism_id integer NOT NULL PRIMARY KEY,
       pub integer NOT NULL REFERENCES pub (pub_id),
       organism integer NOT NULL REFERENCES organism (organism_id)
);

CREATE TABLE person (
       person_id integer NOT NULL PRIMARY KEY,
       name text NOT NULL,
       known_as text,
       email_address text NOT NULL UNIQUE,
       role integer REFERENCES cvterm(cvterm_id) DEFERRABLE INITIALLY DEFERRED  NOT NULL,
       lab INTEGER REFERENCES lab (lab_id),
       session_data text,
       password text,
       added_date timestamp
);

CREATE INDEX person_role_idx ON person(role);

CREATE TABLE curs (
       curs_id integer NOT NULL PRIMARY KEY,
       pub integer NOT NULL REFERENCES pub (pub_id),
       curs_key text NOT NULL,
       creation_date timestamp
);

CREATE TABLE curs_curator (
       curs_curator_id integer NOT NULL PRIMARY KEY,
       curs integer REFERENCES curs(curs_id) NOT NULL,
       curator integer REFERENCES person(person_id) NOT NULL,
       creation_date timestamp NOT NULL,
       accepted_date timestamp
);

CREATE TABLE cursprop (
       cursprop_id integer NOT NULL PRIMARY KEY AUTOINCREMENT,
       curs integer REFERENCES curs(curs_id) NOT NULL,
       type integer REFERENCES cvterm(cvterm_id) NOT NULL,
       value text NOT NULL
);
CREATE INDEX cursprop_type_id_idx ON cursprop(type);
CREATE INDEX cursprop_curs_idx ON cursprop(curs);

CREATE TABLE lab (
       lab_id integer NOT NULL PRIMARY KEY,
       lab_head integer NOT NULL REFERENCES person (person_id),
       name text NOT NULL UNIQUE
);

CREATE TABLE metadata (
       metadata_id integer NOT NULL PRIMARY KEY,
       type integer NOT NULL REFERENCES cvterm(cvterm_id),
       value text NOT NULL
);

-- web sessions
CREATE TABLE sessions (
       id text PRIMARY KEY,
       session_data text,
       expires INTEGER
);

CREATE TABLE gene (
       gene_id integer NOT NULL PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       product text,
       primary_name text,
       organism integer NOT NULL REFERENCES organism (organism_id)
);
CREATE INDEX gene_primary_identifier_idx ON gene (primary_identifier);
CREATE INDEX gene_primary_name_idx ON gene (primary_name);

CREATE TABLE allele (
       allele_id integer NOT NULL PRIMARY KEY,
       primary_identifier text NOT NULL UNIQUE,
       primary_name text,
       description text,
       gene integer NOT NULL REFERENCES gene(gene_id)
);
CREATE INDEX allele_primary_identifier_idx ON allele (primary_identifier);
CREATE INDEX allele_primary_name_idx ON allele (primary_name);


CREATE TABLE genesynonym (
       genesynonym_id integer NOT NULL PRIMARY key,
       gene integer NOT NULL references gene (gene_id),
       identifier text NOT NULL
--       synonym_type integer NOT NULL references cvterm(cvterm_id)
);
CREATE INDEX genesynonym_identifier ON genesynonym (identifier);
