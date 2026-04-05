FROM ruby:3.4-alpine

RUN apk add --no-cache build-base git ripgrep bash openssl-dev

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install --without development test

COPY . .

EXPOSE 9292 9293

ENV NOTIFY_LOG=/tmp/notify.log
ENV BRUTE_READER_CWD=/workspace/docs
ENV BRUTE_CODER_CWD=/workspace/project

CMD ["bundle", "exec", "async-service", "service.rb"]
