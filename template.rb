messages = []

# Gemfile
inject_into_file 'Gemfile',
  after: "source 'https://rubygems.org'\n" do
    "ruby \'#{ENV['RUBY_VERSION'].split('-').last}\'"
end

gsub_file 'Gemfile', /group(.)*$/m, ''
gsub_file 'Gemfile', /gem 'sqlite3'(.)*/, ''
gem 'pg' # DB
gem 'devise' # Devise
gem 'bootstrap-sass', '~> 3.3'
add_source 'https://rails-assets.org' do
  gem 'rails-assets-tether', '>= 1.1.0'
end

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
messages << "Check the Gemfile"

after_bundle do
  # DB
  application_name = ARGV[1]
  gsub_file 'config/database.yml', /^(.)*$/m,
    <<-EOF
default: &default
  adapter: postgresql
  encoding: unicode
  pool: 5
  username: #{application_name}
  password:

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

  messages << "Create new role: sudo -i -u postgres createuser -d -w #{application_name}"
  messages << "Create databases: rails db:create:all"

  # Assets
  run 'mv app/assets/stylesheets/application.css app/assets/stylesheets/application.scss'

  inject_into_file 'app/assets/stylesheets/application.scss',
    after: '*/' do 
    "\n\n@import 'bootstrap-sprockets';\n@import 'bootstrap';"
  end

  inject_into_file 'app/assets/javascripts/application.js',
    before: '//= require_tree .' do
    "//= require bootstrap\n"
  end

  # Test and development environment
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
    after: "require 'rspec/rails'\n" do
    <<-EOF
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

  # Devise
  generate 'devise:install'
  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
    env: 'development'
  inject_into_file 'app/controllers/application_controller.rb',
    after: 'class ApplicationController < ActionController::Base' do
    "\n  before_action :authenticate_user!"
  end
  inject_into_file 'app/views/layouts/application.html.erb',
    after: "<body>\n" do
    <<-EOF
    <div id="messages">
      <% flash.each do |name, message| %>
        <div class="alert alert-<%= name %>">
	  <button class="close" data-dismiss="alert" aria-label="close">
	    &times;
	  </button>
	  <%= message %>
	</div>
      <% end %>
    </div>
    EOF
  end
  inject_into_file 'app/assets/stylesheets/application.scss',
    after: "@import 'bootstrap';\n" do
    <<-EOF

#messages {
  padding: 30px;
  .alert {
    margin: -15px;
    padding: 0;
  }
}
    EOF
  end
  model_name = ask 'What would you like the user model to be called?[user]'
  model_name = 'user' if model_name.blank?
  generate "devise #{model_name}"
  generate 'devise:views'

  messages << 'Check migrations'
  messages << 'Run rails db:migrate'

  # Finish
  git :init
  git add: '.'
  git commit: "-m 'First commit'"

  puts "==========YOUR NEXT STEPS: ============"
  messages.each do |message|
    puts message
  end
end
