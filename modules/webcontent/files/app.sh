#!/bin/sh
cd 
git clone https://github.com/heroku/ruby-rails-sample.git
cd ruby-rails-sample/
bundle
bundle exec  rails server -e production -p 5000 -b 0.0.0.0
