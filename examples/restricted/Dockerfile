FROM ruby:3.4-alpine

RUN apk add --no-cache build-base git ripgrep bash openssl-dev

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --without development test

COPY . .

EXPOSE 9292

ENV NOTIFY_LOG=/tmp/notify.log
ENV BRUTE_CWD=/workspace

CMD ["bundle", "exec", "falcon", "host", "service.rb"]
