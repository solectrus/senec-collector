FROM ruby:3.4.7-alpine3.22 AS builder
RUN apk add --no-cache build-base

# Required for installing gem "openssl" on Alpine Linux
# Remove this after upgrading to Ruby 3.4.8
RUN apk add --no-cache openssl-dev
####

WORKDIR /senec-collector
COPY Gemfile* /senec-collector/
RUN bundle config set path /usr/local/bundle && \
    bundle config set without 'development test' && \
    bundle install --jobs $(nproc) --retry 3 && \
    bundle clean --force && \
    # Remove unneeded files from installed gems (cache, .git, *.o, *.c)
    rm -rf /usr/local/bundle/ruby/*/cache && \
    rm -rf /usr/local/bundle/ruby/*/gems/*/.git && \
    find /usr/local/bundle -type f \( \
    -name '*.c' -o \
    -name '*.o' -o \
    -name '*.log' -o \
    -name 'gem_make.out' \
    \) -delete && \
    find /usr/local/bundle -name '*.so' -exec strip --strip-unneeded {} +

FROM ruby:3.4.7-alpine3.22
LABEL maintainer="georg@ledermann.dev"

# Add tzdata to get correct timezone
RUN apk add --no-cache tzdata

# Required for using gem "openssl" on Alpine Linux
# Remove this after upgrading to Ruby 3.4.8
RUN apk add --no-cache openssl ca-certificates && \
    update-ca-certificates
####

ENV \
    # Decrease memory usage
    MALLOC_ARENA_MAX=2 \
    # Enable YJIT
    RUBYOPT=--yjit

# Move build arguments to environment variables
ARG BUILDTIME
ENV BUILDTIME=${BUILDTIME}

ARG VERSION
ENV VERSION=${VERSION}

ARG REVISION
ENV REVISION=${REVISION}

WORKDIR /senec-collector

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY . /senec-collector/

ENTRYPOINT ["bundle", "exec", "app.rb"]
