ARG CRVERSION=1.8.2
ARG ALPINE=3.18 
FROM crystallang/crystal:$CRVERSION-alpine AS builder
#hadolint ignore=DL3018
RUN apk add --no-cache sqlite-static yaml-static

ARG release

WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/

# Required for fetching player dependencies
COPY ./scripts/ ./scripts/
COPY ./assets/ ./assets/
COPY ./videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all \
    --link-flags "-lxml2 -llzma"    
RUN if [[ "${release}" == 1 ]] ; then \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        echo 'Not buidling release nor disabled_quic' ; \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM alpine:$ALPINE
ARG ALPINE

#hadolint ignore=DL3018
RUN apk add --no-cache rsvg-convert ttf-opensans tini
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY --chown=invidious ./config/config.* ./config/
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
COPY --chown=invidious ./config/config.* ./config/
#hadolint ignore=DL3018
RUN apk add --no-cache librsvg ttf-opensans wget\
    && mv -n config/config.example.yml config/config.yml \
    && sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml \
    && chmod o+rX -R ./assets ./config ./locales
HEALTHCHECK --interval=30s  --timeout=5s --retries=2 \
      CMD wget -nv --tries=1 --spider http://127.0.0.1:3000/api/v1/trendings || exit 1
EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]