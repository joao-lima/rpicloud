FROM openjdk:11

LABEL maintainer="github.com/lucas-fs"

ENV DEBIAN_FRONTEND noninteractive
ENV YCSB_VERSION 0.18.0
ENV HBASE_CLIENT_VERSION 2.2.7
ENV YCSB_HOME /opt/ycsb
ENV JDBC_HOME /opt/ycsb/jdbc-binding

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE 1

RUN curl --progress-bar -Lo /tmp/ycsb-${YCSB_VERSION}.tar.gz https://github.com/lucas-fs/YCSB/releases/download/${YCSB_VERSION}/ycsb-${YCSB_VERSION}.tar.gz \
    && cd /opt \
    && tar -xvf /tmp/ycsb-${YCSB_VERSION}.tar.gz \
    && mv ycsb-${YCSB_VERSION}-SNAPSHOT /opt/ycsb  \
    && rm -rf /tmp/ycsb-${YCSB_VERSION}.tar.gz 

RUN cd /opt \
    && curl --progress-bar -Lo ${YCSB_HOME}/slf4j-api-1.7.30.jar https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.30/slf4j-api-1.7.30.jar \
    && curl --progress-bar -Lo ${YCSB_HOME}/slf4j-simple-1.7.30.jar https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.7.30/slf4j-simple-1.7.30.jar 

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	nano \
	wget \
	openssh-client \
	git \
	gnupg2 \
	python \
	python3 \
	python3-pip \
	; \
	rm -rf /var/lib/apt/lists/*

#
# Install PostgreSQL client version 13
#RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

#RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' | \
#	tee  /etc/apt/sources.list.d/pgdg.list

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	postgresql-client \
	; \
	rm -rf /var/lib/apt/lists/*

## Install Cassandra client (cqlsh)
RUN pip install cqlsh

# Create alias for ycsb and export classpath
RUN echo 'alias ycsb="$YCSB_HOME/bin/ycsb"' >> /root/.bashrc
ENV PATH $YCSB_HOME/bin/:$PATH
ENV CLASSPATH=$YCSB_HOME/slf4j-api-1.7.30.jar:$YCSB_HOME/slf4j-simple-1.7.30.jar:$JDBC_HOME/lib/postgresql-42.2.14.jar

## Include Hbase-client bin in PATH
##ENV HBASE_HOME /opt/hbase-${HBASE_CLIENT_VERSION}-client
##ENV PATH $HBASE_HOME/bin/:$PATH
#
## Create volumes for outputs and scripts
RUN mkdir /ycsb_outputs /scripts \
	&& chmod 777 /ycsb_outputs /scripts
#
VOLUME /ycsb_outputs
VOLUME /scripts

CMD ["sh", "-c", "tail -f /dev/null"]

