FROM alpine:latest AS builder
RUN apk add bash curl
WORKDIR /build
COPY unleash /build/
COPY lib/ /build/lib/
RUN bash -n unleash lib/*.sh

FROM alpine:latest
RUN apk add --no-cache bash curl
COPY --from=builder /build/ /opt/unleash/
RUN ln -s /opt/unleash/unleash /usr/local/bin/unleash
WORKDIR /opt/unleash
ENTRYPOINT ["/opt/unleash/unleash"]
CMD ["--help"]
