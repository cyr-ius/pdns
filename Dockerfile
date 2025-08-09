FROM alpine:3.19
LABEL Name=pdns
LABEL Version=4.8.3
LABEL Maintainer=Cyr-ius
RUN apk add --no-cache pdns pdns-backend-sqlite3 pdns-backend-mariadb pdns-backend-geoip pdns-backend-mysql mariadb-client mysql-client pdns-doc python3 py3-pip
RUN pip3 install --break-system-packages --no-cache-dir envtpl
RUN mkdir -p /etc/pdns/pdns.d /var/run/pdns /var/lib/powerdns /etc/pdns/templates.d
RUN chown pdns:pdns /var/run/pdns /var/lib/powerdns /etc/pdns/pdns.d /etc/pdns/templates.d
ENV PDNS_SETUID=pdns
ENV PDNS_SETGID=pdns
ENV PDNS_LOCAL_ADDRESS=0.0.0.0,::
ENV PDNS_LAUNCH=gsqlite3
ENV PDNS_GUARDIAN=yes
ENV PDNS_INCLUDE_DIR=/etc/pdns/pdns.d
COPY pdns.conf.tpl /
COPY docker-entrypoint.sh /
EXPOSE 53 53/udp
EXPOSE 53 53/tcp
EXPOSE 5353 5353/UDP
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/usr/sbin/pdns_server" ]
