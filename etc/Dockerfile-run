# command: docker build -f Dockerfile -t=pombase/canto-run:v8 .
FROM pombase/canto-base:v8

RUN echo deb http://http.debian.net/debian jessie-backports main >> /etc/apt/sources.list; apt update

RUN apt-get -y install -t jessie-backports openjdk-8-jdk

RUN (cd /usr/local/bin/; ln -s /usr/local/java-se-8u40-ri/bin/* .)

RUN (cd /usr/local/bin/; curl -L http://build.berkeleybop.org/userContent/owltools/owltools > owltools; chmod a+x owltools)
