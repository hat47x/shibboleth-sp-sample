FROM amazonlinux:2023

RUN dnf -y update && \
    dnf -y install \
      ca-certificates \
      curl \
      httpd \
      mod_ssl \
      procps-ng && \
    curl -fsSL -o /tmp/shibboleth-repo.rpm \
      https://shibboleth.net/downloads/service-provider/latest/rpms/shibboleth-repo-latest.noarch.rpm && \
    dnf -y install /tmp/shibboleth-repo.rpm && \
    dnf -y install shibboleth && \
    rm -f /tmp/shibboleth-repo.rpm && \
    dnf clean all

COPY shibboleth/ /etc/shibboleth/
COPY apache/shib.conf /etc/httpd/conf.d/shib.conf
COPY html/ /var/www/html/
COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    mkdir -p /etc/shibboleth/certs /var/run/shibboleth /var/log/shibboleth && \
    chown -R shibd:shibd /var/run/shibboleth /var/log/shibboleth

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
