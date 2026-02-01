# Latest Ubuntu 18.04 image as of Fri May 8 03:57:47 UTC 2020
FROM ubuntu@sha256:cd1dba651b3080c3686ecf4e3c4220f026b521fb76978881737d24f200828b2b

ARG DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y jq git wget curl rsync && \
    wget -qO wo wops.cc && \
    git config --global user.email "nobody@example.com" && \
    git config --global user.name "nobody" && \
    bash wo && \
    wo stack install --nginx --mysql --php74 && \
    rm wo && rm -rf /var/lib/apt/lists/*

COPY *.sh /
COPY ./wp-content /wp-content
RUN chmod +x /*.sh
ENTRYPOINT ["/entrypoint.sh"]
