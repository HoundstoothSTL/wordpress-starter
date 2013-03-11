set :stages, %w(production staging)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :github_username, "{{githubuser}}" 			# TODO
set :application, "{{projectname}}" 			# TODO

set :repository, "git@github.com:/#{github_username}/#{application}.git"
set :scm, :git
set :use_sudo, false

ssh_options[:forward_agent] = true
set :deploy_via, :remote_cache
set :copy_exclude, [".git", ".DS_Store", ".gitignore", ".gitmodules"]
set :keep_releases, 5
set :git_enable_submodules, 1
set :wp_multisite, 0 							# TODO Set to 1 if multisite

namespace :custom_task do
    desc "Creates symlink to shared/uploads folder"
    task :uploads_link, :roles => :app do
        run "ln -nfs #{shared_path}/uploads #{release_path}/site/wp-content/uploads"
    end
end
after "deploy:finalize_update", "custom_task:uploads_link"