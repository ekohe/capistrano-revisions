# capistrano-revisions

This gem provides `cap deploy:revisions` to Capistrano 3.

## Installation

Add this line to your application's Gemfile:

    gem 'capistrano-revisions', :require => false

Add this to your deploy.rb

    set :redmine_api_key, 'XXXXXXXXXXXX'
    set :redmine_wiki_xml_url, 'https://redmine.com/projects/project_name/revisions.xml'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-revisions

## Usage

Add below to Capfile:

    require 'capistrano-revisions'

and run below to append the revision history to a Redmine Wiki

    $ bundle exec cap <stage> deploy:revisions
