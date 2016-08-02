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

  # Layouts
  inject_into_file 'app/views/layouts/application.html.erb',
    after: "</title>\n" do
    <<-HTML
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    HTML
  end

  inject_into_file 'app/views/layouts/application.html.erb',
    after: "<body>\n" do
    <<-HTML
    <%= render "layouts/web_console" %>
    <%= render "layouts/header" %>
    <%= render "layouts/messages" %>
    HTML
  end

  ## Web console
  file 'app/views/layouts/_web_console.html.erb', <<-HTML
<% if Rails.env.development? %>
  <button id="console-toggle" class="btn btn-link btn-lg">
    <span class="glyphicon glyphicon-console"></span>
  </button>
  <% console %>
<% end %>
  HTML
  inject_into_file 'app/assets/stylesheets/application.scss',
    after: "@import 'bootstrap';\n" do
    <<-CSS
#console-toggle {
  position: absolute;
  top: 100px;
  left: -47px;
  width: 50px;
  border-right: 3px solid #333;
  transition: left 0.5s ease-in-out;
  &:hover {
    left: 0;
  }
}
    CSS
  end
  file 'app/assets/javascripts/web_console.coffee', <<-COFFEE
document.addEventListener "turbolinks:load", () ->
  $('#console').hide()

  $('#console-toggle').click () ->
    $('#console').toggle()
  COFFEE

  ## Header
  file 'app/views/layouts/_header.html.erb', <<-HTML
<header class="navbar navbar-default">
  <nav class="container-fluid">
    <div class="navbar-header">
      <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar-collapsed" aria-expanded="false">
        <span class="sr-only">Toggle navigation</span>
	<span class="icon-bar"></span>
	<span class="icon-bar"></span>
	<span class="icon-bar"></span>
      </button>
      <%= link_to "#{application_name.capitalize}", root_path, class: "navbar-brand" %>
    </div>
    <div class="collapse navbar-collapse" id="navbar-collapsed">
      <ul class="nav navbar-nav">
        <li class="active">
	  <a href="#">Link</a>
	</li>
	<li class="dropdown">
	  <a href="#" class="dropdown-toggle" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false">
	    Dropdown <span class="caret"></span>
	  </a>
	  <ul class="dropdown-menu">
	    <li><a href="#">One</a></li>
	    <li><a href="#">Two</a></li>
	    <li><a href="#">Three</a></li>
	  </ul>
	</li>
      </ul>
      <form class="navbar-form navbar-left">
	<div class="form-group">
	  <input type="text" class="form-control" placeholder="Search">
	</div>
	<button type="submit" class="btn btn-default">Find</button>
      </form>
      <p class="navbar-text navbar-right">Signed in as User</p>
    </div>
  </nav>
</header>
  HTML

  ## Flash
  file 'app/views/layouts/_messages.html.erb', <<-HTML
<div id="messages">
  <% flash.each do |name, message| %>
    <% name = 'danger' if name == 'alert' %>
    <div class="alert alert-<%= name %>">
      <button class="close" data-dismiss="alert" aria-label="close">
	&times;
      </button>
      <%= message %>
    </div>
  <% end %>
</div>
  HTML

  if yes?('Is it ok if the user model will be called `user`?')
    model_name = 'user'
  else
    model_name = ask 'What would you like the user model to be called?'
  end
  model_name = 'user' if model_name.blank?

  # Welcome page
  generate 'controller welcome index'

  route "root to: 'welcome#index'"

  inject_into_file 'app/controllers/welcome_controller.rb',
    after: 'class WelcomeController < ApplicationController' do
    "\n  skip_before_action :authenticate_#{model_name}!\n"
  end

  # Devise
  generate 'devise:install'
  generate "devise #{model_name}"
  generate 'devise:views'

  environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }",
    env: 'development'
  inject_into_file 'app/controllers/application_controller.rb',
    after: 'class ApplicationController < ActionController::Base' do
    "\n  before_action :authenticate_#{model_name}!"
  end
  messages << 'Check migrations'
  messages << 'Run rails db:migrate'

  # Finish
  inject_into_file '.gitignore',
    after: '/.bundle' do
    "\n\n*.swp"
  end
  git :init
  git add: '.'
  git commit: "-m 'First commit'"

  puts "==========YOUR NEXT STEPS: ============"
  messages.each do |message|
    puts message
  end
end
