FROM ruby:3.1.3-alpine AS Builder
RUN apk add --no-cache build-base

WORKDIR /senec-collector
COPY Gemfile* /senec-collector/
RUN bundle config --local frozen 1 && \
    bundle config --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    bundle clean --force

FROM ruby:3.1.3-alpine
LABEL maintainer="georg@ledermann.dev"
ENV MALLOC_ARENA_MAX 2
WORKDIR /senec-collector

COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY . /senec-collector/

ENTRYPOINT bundle exec src/main.rb
