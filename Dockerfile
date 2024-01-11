FROM ruby:3.2.2-alpine AS Builder
RUN apk add --no-cache build-base

WORKDIR /senec-collector
COPY Gemfile* /senec-collector/
RUN bundle config --local frozen 1 && \
    bundle config --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    bundle clean --force

FROM ruby:3.2.2-alpine
LABEL maintainer="georg@ledermann.dev"

# Decrease memory usage
ENV MALLOC_ARENA_MAX 2

# Move build arguments to environment variables
ARG BUILDTIME
ENV BUILDTIME ${BUILDTIME}

ARG VERSION
ENV VERSION ${VERSION}

ARG REVISION
ENV REVISION ${REVISION}

WORKDIR /senec-collector

COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY . /senec-collector/

ENTRYPOINT bundle exec app/main.rb
