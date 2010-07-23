PRAGMA foreign_keys=ON;

CREATE TABLE pub (
       pub_id integer NOT NULL PRIMARY KEY,
       pubmedid text UNIQUE,
       title text,
       authors text
);

CREATE TABLE cv (
       cv_id integer NOT NULL PRIMARY KEY,
       name text NOT NULL,
       definition text
       );

CREATE TABLE cvterm (
       cvterm_id integer NOT NULL PRIMARY KEY,
       cv_id int NOT NULL references cv (cv_id),
       name varchar(1024) NOT NULL,
       definition text,
       is_obsolete int NOT NULL default 0,
       is_relationshiptype int NOT NULL default 0
     );
CREATE INDEX cvterm_idx1 ON cvterm (cv_id);
CREATE INDEX cvterm_idx2 ON cvterm (name);
CREATE TABLE organism (
       	organism_id integer NOT NULL PRIMARY KEY,
        abbreviation varchar(255) null,
        genus varchar(255) NOT NULL,
        species varchar(255) NOT NULL,
        common_name varchar(255) null,
        comment text null
);

CREATE TABLE pub_organism (
       pub_organism_id integer NOT NULL PRIMARY KEY,
       pub integer NOT NULL REFERENCES pub (pub_id),
       organism integer NOT NULL REFERENCES organism (organism_id)
);

CREATE TABLE pubstatus (
       pubstatus_id integer NOT NULL PRIMARY KEY,
       pub_id integer NOT NULL REFERENCES pub (pub_id),
       status integer NOT NULL REFERENCES cvterm (cvterm_id)
);

CREATE TABLE person (
       person_id integer NOT NULL PRIMARY KEY,
       shortname text,
       longname text NOT NULL,
       networkaddress text NOT NULL UNIQUE,
       role text NOT NULL,
       lab INTEGER REFERENCES lab (lab_id),
       session_data text,
       password text
);

CREATE TABLE curs (
       curs_id integer NOT NULL PRIMARY KEY,
       community_curator integer NOT NULL REFERENCES person (person_id),
       pub integer NOT NULL REFERENCES pub (pub_id),
       curs_key text NOT NULL
);

CREATE TABLE lab (
       lab_id integer NOT NULL PRIMARY KEY,
       lab_head integer NOT NULL REFERENCES person (person_id),
       name text NOT NULL
);

CREATE TABLE sessions (
       id           text PRIMARY KEY,
       session_data text,
       expires      INTEGER
);
