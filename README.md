# capistrano-revisions

This gem provides `cap deploy:revisions` to Capistrano 3 which does:

1. Creates a Redmine Wiki page with a history of all the commits and when they were deployed.
2. Emails user defined in :revisions_email about what commits were just deployed. 

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-revisions', :require => false

Set your configuration variables in deploy.rb

    set :cr_email, 'user@email.com' #who will receive the notification emails
    set :cr_redmine_key, 'XXXXXXXXXXXX'
    set :cr_redmine_url, 'https://redmine.com/projects/project_name/revisions_#{fetch:stage}.xml' # so you don't overwrite your staging deployment history when you deploy to production :doge:

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-revisions

Make sure your application has a tmp directory on the server.  You may need to create it in your shared directory and then symlink it over

    set :linked_dirs, %w{tmp}

## Usage

Add below to Capfile:

    require 'capistrano-revisions'

and run below to append the revision history to a Redmine Wiki

    $ bundle exec cap <stage> deploy:revisions
