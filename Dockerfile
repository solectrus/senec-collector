FROM ruby:3.0.2-alpine
LABEL maintainer="georg@ledermann.dev"

WORKDIR /senec-collector

COPY Gemfile* /senec-collector/
RUN bundle config --local frozen 1 && \
    bundle config --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    bundle clean --force

COPY . /senec-collector/
