FROM ruby:3.1.1-slim-bullseye

RUN apt-get update && apt-get install -y \ 
  build-essential \ 
  gnupg2 \
  lsb-release \
  wget

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y \ 
  supervisor \
  software-properties-common \
  locales \
  postgresql-client-12 \
  postgresql-12

RUN gem install aws-sdk-s3

COPY script.rb script.rb

CMD ["ruby", "script.rb"]
