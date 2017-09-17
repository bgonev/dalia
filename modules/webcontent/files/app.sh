#!/bin/sh
cd
git clone https://github.com/heroku/ruby-rails-sample.git
cd ruby-rails-sample/
bundle
bundle exec rake bootstrap RAILS_ENV=production DATABASE_URL="postgres://ruby-rails-sample:Password1@sql1/ruby-rails-sample_production"
/usr/local/heroku/bin/heroku local
