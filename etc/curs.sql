PRAGMA foreign_keys=ON;

CREATE TABLE organism (
	organism_id integer PRIMARY KEY,
        data text NOT NULL
);

CREATE TABLE gene (
       primary_id text PRIMARY KEY,
       organism integer NOT NULL REFERENCES organism(organism_id),
       data text NOT NULL
);

CREATE TABLE annotation (
       annotation_id integer PRIMARY KEY,
       status text NOT NULL,  -- "new", "deleted", "unchanged"
       pub integer REFERENCES pub(pub_id),
       type text NOT NULL, -- "go function", "ortholog", "phenotype"
       data text NOT NULL,
       -- include type as the there may be a go term and ortholog with the same
       -- chado id
       UNIQUE (annotation_id, status, type)
);

CREATE TABLE pub (
       pub_id integer primary key,
       data text NOT NULL
);
