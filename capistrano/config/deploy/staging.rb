#Where we're deploying to on the server
set :deploy_to, "/home/{{remoteuser}}/public/staging.{{domain}}/public" #TODO No trailing slash 

#Remote Server credentials
set :user, "{{remoteuser}}" #TODO

set :domain, "{{remotehost}}" #TODO
set :password, "" #TODO
set :port, "22" #TODO
server "#{user}@#{domain}", :app #This line doesn't need to change

# This is useful if apache or something needs to belong to a group. I added
# this when working on a Med Temple DV server where the files needed to be
# a part of the group placln. Don't forget to uncomment out the line near the
# bottom of the document to turn this on.

set :group, "apache" #TODO

# Alright, that's it! Stop editing!
#
# Now Begin the magic

#Symlink .htaccess to the release folder so it doesn't get overwritten
namespace :custom_task do
    task :htaccess, :roles => :app do
        #run "ln -nfs #{shared_path}/wp-config-staging.php #{release_path}/wp-config-staging.php"
        run "ln -nfs #{shared_path}/.htaccess #{release_path}/.htaccess"
    end
end

after "deploy:finalize_update", "custom_task:htaccess"

#Create env_staging file
namespace :custom_task do
    desc "Add env_staging file to releases dir"
    task :touch_staging, :roles => :app do
      run "touch #{releases_path}/env_staging"
    end
end
after "deploy:finalize_update", "custom_task:touch_staging"

#Create backups and uploads directory on setup
namespace :custom_task do
  desc "Add needed shared directories"
  task :add_shares, :roles => :app do
    run "mkdir #{shared_path}/backups"
    run "mkdir #{shared_path}/uploads"
    run "chmod -R o=g #{shared_path}/uploads"
  end
end
after "deploy:setup", "custom_task:add_shares"