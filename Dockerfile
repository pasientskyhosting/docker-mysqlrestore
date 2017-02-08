FROM debian:jessie
MAINTAINER Joakim Karlsson <jk@patientsky.com>

RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && apt-get install -y --no-install-recommends \
                apt-transport-https ca-certificates \
                pwgen \
        && rm -rf /var/lib/apt/lists/*

RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A
RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 9334A25F8507EFA5

RUN echo 'deb https://repo.percona.com/apt jessie main' > /etc/apt/sources.list.d/percona.list

ENV PERCONA_MAJOR 5.6
ENV PERCONA_VERSION 5.6.34-79.1-1.jessie


# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
RUN { echo percona-server-server-$PERCONA_MAJOR percona-server-server/root_password password 'unused'; echo percona-server-server-$PERCONA_MAJOR percona-server-server/root_password_again password 'unused'; } | debconf-set-selections \
        && apt-get update \
        && apt-get install -y \
        percona-server-server-$PERCONA_MAJOR=$PERCONA_VERSION \
        percona-xtrabackup \
        wget \
        && rm -rf /var/lib/apt/lists/* \
# comment out any "user" entires in the MySQL config ("docker-entrypoint.sh" or "--user" will handle user switching)
        && sed -ri 's/^user\s/#&/' /etc/mysql/my.cnf \
# purge and re-create /var/lib/mysql with appropriate ownership
        && rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld \
        && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
        && chmod 777 /var/run/mysqld

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
        && echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
        && mv /tmp/my.cnf /etc/mysql/my.cnf

VOLUME ["/var/lib/mysql", "/var/log/mysql"]


COPY ps-entry.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD [""]