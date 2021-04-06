FROM arm32v7/ruby:3.0.1-alpine
LABEL maintainer="georg@ledermann.dev"

WORKDIR /senec-collector

COPY Gemfile* /senec-collector/
RUN bundle config --local frozen 1 && \
    bundle install -j4 --retry 3

COPY . /senec-collector/
