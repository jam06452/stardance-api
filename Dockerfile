# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=trixie-20260610-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.19.5-erlang-28.4.2-debian-trixie-20260610-slim
#
ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.4.2
ARG DEBIAN_VERSION=trixie-20260610-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY priv priv

COPY lib lib

RUN mix compile

COPY assets assets

RUN mix assets.deploy

COPY config/runtime.exs config/

COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS final

RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/stardance ./

COPY --chown=nobody:root entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER nobody

ENTRYPOINT ["/app/entrypoint.sh"]

CMD ["/app/bin/server"]
