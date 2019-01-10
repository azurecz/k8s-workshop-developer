FROM kyma/docker-nginx
COPY src/ /var/www
COPY startup.sh /startup.sh
COPY version /version
ENTRYPOINT [ "/bin/bash", "/startup.sh" ]
