FROM ruby:4.0.6-alpine AS builder
RUN apk add --no-cache build-base

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

FROM ruby:4.0.6-alpine
LABEL maintainer="georg@ledermann.dev"

# Add tzdata to get correct timezone
RUN apk add --no-cache tzdata

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

# Git-describe version (e.g. v0.10.1-3-g2d8f177), which - unlike VERSION -
# is a real version on branch builds, too. Used by HELIOS to show the version.
ARG COMMIT_VERSION
ENV COMMIT_VERSION=${COMMIT_VERSION}

WORKDIR /senec-collector

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY . /senec-collector/

ENTRYPOINT ["bundle", "exec", "app.rb"]
