FROM python:3.11.9-bullseye

ARG DEBIAN_FRONTEND=noninteractive

ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8

RUN apt-get -y update \
    && apt-get -y install jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pip install cowsay

COPY --from=root . /app

COPY --from=bins_hi hi_/hi /usr/local/bin/hi

ENTRYPOINT ["/usr/local/bin/python3"]

CMD ["/app/say.py"]