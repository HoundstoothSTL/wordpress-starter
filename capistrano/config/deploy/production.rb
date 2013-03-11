# What do our folders look like on the remote server
set :deploy_to, "/home/{{remoteuser}}/public/{{domain}}/public"   #TODO
set :home_directory, "/home/{{remoteuser}}"                       #TODO

#Remote Server credentials
set :user, "{{remoteuser}}"                                       #TODO
set :domain, "{{remotehost}}"                                     #TODO
set :password, ""                                                 #TODO (if not using SSH keys)
set :port, "22"                                                   #TODO
server "#{user}@#{domain}", :app #This line doesn't need to change

# This is useful if apache or something needs to belong to a group.
set :group, "apache" #TODO

#Symlink .htaccess to the release folder so it doesn't get overwritten
namespace :custom_task do
    task :syms, :roles => :app do
        puts "Running Symlinks..."
        run "ln -nfs #{shared_path}/.htaccess #{release_path}/.htaccess"
    end
end

after "deploy:finalize_update", "custom_task:syms"

#Create environment file
namespace :custom_task do
    desc "Add env_production file to releases dir"
    task :touch_production, :roles => :app do
      run "touch #{releases_path}/env_production"
    end
end
after "deploy:finalize_update", "custom_task:touch_production"

#Fix Permissions
#namespace :custom_task do
#  desc "Fix file & directory permissions on server"
#  task :fix_permissions, :roles => :app do
#    run "cd #{release_path} && chown -R #{user}:#{group} . && find . -type d -print0 | xargs -0 chmod 755"
#    run "cd #{shared_path}/uploads && chown -R #{user}:#{group} ."
#  end
#end
#after "deploy:finalize_update", "custom_task:fix_permissions"

#Create backups and uploads directory
namespace :deploy do
  desc "Add needed shared directories"
  task :add_shares, :roles => :app do
    run "mkdir #{shared_path}/backups"
    run "mkdir #{shared_path}/uploads"
    run "chmod -R o=g #{shared_path}/uploads"
  end
end
after "deploy:setup", "deploy:add_shares"

#Create backups and uploads directory
namespace :deploy do
  desc "Setup S3 backup directories"
  task :s3_backup, :roles => :app do
    run "mkdir #{home_directory}/tmp"
    run "mkdir #{home_directory}/s3backup"
  end
end
after "deploy:setup", "deploy:s3_backup"