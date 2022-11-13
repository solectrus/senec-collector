FROM ruby:3.1.2-alpine
LABEL maintainer="georg@ledermann.dev"
RUN apk add --no-cache build-base

WORKDIR /senec-collector

ENV MALLOC_ARENA_MAX 2

COPY Gemfile* /senec-collector/
RUN bundle config --local frozen 1 && \
    bundle config --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    bundle clean --force

COPY . /senec-collector/

ENTRYPOINT bundle exec src/main.rb
