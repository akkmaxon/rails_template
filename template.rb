# Gemfile
inject_into_file 'Gemfile',
  after: "source 'https://rubygems.org'\n" do
    "ruby \'#{ENV['RUBY_VERSION'].split('-').last}\'"
end

gsub_file 'Gemfile', /group(.)*$/m, ''

gem 'pg'
gem 'devise'
gem 'bootstrap-sass'

gem_group :development, :test do
  gem 'byebug'
  gem 'rspec-rails'
  gem 'faker'
end

gem_group :development do
  gem 'web-console'
  gem 'better_errors'
  gem 'listen'
  gem 'spring'
  gem 'spring-watcher-listen'
end

gem_group :test do
  gem 'factory_girl_rails'
  gem 'database_cleaner'
  gem 'poltergeist'
end

gem 'rails_12factor', group: 'production'

run 'bundle install'

# RSpec
run 'rm -rf test/'

generate 'rspec:install'

gsub_file 'spec/spec_helper.rb', /^(.)*$/m,
  <<-EOF
RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = [:expect]
  end

  if config.files_to_run.one?
    config.default_formatter = 'doc'
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
end
EOF

inject_into_file 'spec/rails_helper.rb',
  after: "require 'rspec/rails'\n" do <<-EOF
require 'capybara/poltergeist'

Capybara.default_driver = :poltergeist
EOF
end

gsub_file 'spec/rails_helper.rb',
  'config.use_transactional_fixtures = true',
  'config.use_transactional_fixtures = false'

inject_into_file 'spec/rails_helper.rb',
  before: "\nend\n" do
  <<-EOF

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, type: :feature) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.include Warden::Test::Helpers, type: :feature
  config.after(type: :feature) { Warden.test_reset! }
EOF
end
=begin
# DB -- replace application_name
gsub_file 'config/database.yml', /^(.)*$/m,
  <<-EOF
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  username: #{application_name}
  password: #{application_name}

development:
  <<: *default
  database: #{application_name}_development

test:
  <<: *default
  database: #{application_name}_test

production:
  <<: *default
  database: #{application_name}_production
  username: #{application_name}
  password: <%= ENV['#{application_name.upcase}_DATABASE_PASSWORD'] %>
EOF
=end

# Assets
run 'mv app/assets/stylesheets/application.css app/assets/stylesheets/application.scss'

inject_into_file 'app/assets/stylesheets/application.scss',
  after: '*/' do <<-EOF

@import 'bootstrap-sprockets';
@import 'bootstrap';
EOF
end

inject_into_file 'app/assets/javascripts/application.js',
  before: '//= require_tree .' do
  "//= require bootstrap\n"
end
