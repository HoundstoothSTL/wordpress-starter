#!/bin/bash
# Author: Rob Bennet
# Company: Houndstooth
# Github: https://github.com/HoundstoothSTL 
# Description: Build out a WordPress environment for local development of a new project. 
#              Optionally set up deployment with Capistrano and an Amazon S3 backup system to 
#			   transfer to your remote machine.
#
# Version 0.1.0

# Fixes: Need to rework the generated salt piece for wp-config.php

## Required program(s) ##
#########################
req_progs=(ruby)
for p in ${req_progs[@]}; do
  hash "$p" 2>&- || \
  { echo >&2 " Required program \"$p\" not installed."; exit 1; }
done

## Dynamic Variables ##
#######################
USER="$(whoami)"
IP="127.0.0.1"
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
GSED="$(which gsed)"
OPEN="$(which open)"
MYSQL="$(which mysql)"
APACHECTL="$(which apachectl)"

## User and Project Variables ##
################################
VHOSTS_DIR="/Users/${USER}/vhosts"								#TODO
SITES_DIR="/Users/${USER}/Dropbox/Houndstooth/Sites"			#TODO
DEPLOY_DIR="/Users/${USER}/Dropbox/Houndstooth/code/deploy"		#TODO
EMAIL="rob@madebyhoundstooth.com"								#TODO
GITHUB_USER="HoundstoothSTL"									#TODO

## Color Profiles ##
####################
CYAN="\033[1;36m"
LIGHTRED="\033[1;31m"
LIGHTGRAY="\033[1;30m"
LIGHTCYAN="\033[1;36m"
WHITE="\033[1;37m"
LIGHTGREEN="\033[1;32m"
TITLE=$LIGHTCYAN
Q=$LIGHTGRAY
M=$CYAN
A=$LIGHTRED
YN=$WHITE
QMARK=$LIGHTGREEN

## Text Decoration variables ##
###############################
TXTUND=$(tput sgr 0 1)
TXTBLD=$(tput bold)
TXTRST=$(tput sgr0)

if [ -z $1 ]; then
	echo "No domain name given"
	exit 1
fi
DOMAIN=$1

# Ask for the administrator password upfront
echo -e $CYAN"We will need sudo for the hosts file, get it out of the way..."$WHITE
sudo -v

# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
 
# check the domain is valid!
PATTERN="^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$";
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating host for:" $DOMAIN
else
	echo "invalid domain name"
	exit 1
fi

PROJECTNAME=
while [ -z $PROJECTNAME ]
do 
	echo -e -n $QMARK'[?] '$Q'What is the project name? ' $WHITE
	read PROJECTNAME
done

# Add the domain to /etc/hosts
echo -e $CYAN"Adding ${DOMAIN} to hosts file..."$WHITE
echo -e "\n${IP} ${DOMAIN}" | sudo tee -a /etc/hosts >> /dev/null

# Create the vhost config 
cp $THIS_DIR/vhost.conf $VHOSTS_DIR/vhost.conf && cd $VHOSTS_DIR && mv vhost.conf $PROJECTNAME.conf

# Replace vhosts.conf template parts with project info
$GSED -i "s/{{sitesdir}}/${SITES_DIR}/g" $PROJECTNAME.conf
$GSED -i "s/{{projectname}}/${PROJECTNAME}/g" $PROJECTNAME.conf
$GSED -i "s/{{user}}/${USER}/g" $PROJECTNAME.conf
$GSED -i "s/{{email}}/${EMAIL}/g" $PROJECTNAME.conf
$GSED -i "s/{{domain}}/${DOMAIN}/g" $PROJECTNAME.conf

# Create Local DB for this project
echo -e $CYAN"We'll need the" $LIGHTRED "local" $CYAN "MYSQL root password..." $WHITE
MYSQL_PASS=
while [ -z $MYSQL_PASS ]
do 
	echo -e -n $QMARK'[?] '$Q'Local MYSQL Root Password: ' $WHITE
	read MYSQL_PASS
done
 
QUERY_1="CREATE DATABASE IF NOT EXISTS ${PROJECTNAME}_dev;"
QUERY_2="GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
QUERY_3="FLUSH PRIVILEGES;"
SQL="${QUERY_1}${QUERY_2}${QUERY_3}"
 
echo -e $CYAN"Creating the" $LIGHTRED "${PROJECTNAME}_dev" $CYAN "database" $WHITE
$MYSQL -uroot -p$MYSQL_PASS -e "${SQL}";
echo -e $CYAN"Database Created" $WHITE

# Go to project directory
cd $SITES_DIR

# Pull down Topcoat WP starter
echo -e $CYAN"Pulling down Topcoat WP starter..."$WHITE
git clone git@github.com:HoundstoothSTL/topcoat.git

# Rename topcoat to project name
mv topcoat $PROJECTNAME

# Go into project 
cd $PROJECTNAME

# Get rid of .git database
rm -rf .git

# Go into themes directory
cd site/wp-content/themes

echo -e $CYAN"Pulling down WP Aldren theme..."$WHITE
# Clone Bolt starter theme
git clone git@github.com:HoundstoothSTL/wp-aldren.git

# Go into theme
cd wp-aldren

# Get rid of .git database
rm -rf .git

##############################
## Setup Remote Credentials ##
##############################
REMOTE=
while [ -z $REMOTE ]
do 
	echo -e -n $QMARK'[?] '$Q'Setup remote info? ' $YN'(y/n) '
	read REMOTE
done

if [[ "${REMOTE}" =~ ^[Yy]$ ]]
	then
		REMOTE_HOST=
		while [ -z $REMOTE_HOST ]
		do 
			echo -e -n $QMARK'[?] '$Q'Remote host address: ' $WHITE
			read REMOTE_HOST
		done

		REMOTE_USER=
		while [ -z $REMOTE_USER ]
		do 
			echo -e -n $QMARK'[?] '$Q'Remote user: ' $WHITE
			read REMOTE_USER
		done

		REMOTE_DB_PASS=
		while [ -z $REMOTE_DB_PASS ]
		do 
			echo -e -n $QMARK'[?] '$Q'Remote DB Password: ' $WHITE
			read REMOTE_DB_PASS
		done

		PUBLIC_URL=
		while [ -z $PUBLIC_URL ]
		do 
			echo -e -n $QMARK'[?] '$Q'Public URL: ' $WHITE
			read PUBLIC_URL
		done
fi

cd $SITES_DIR/$PROJECTNAME

# Generate random string for table prefix
if [ -n "$1" ]  
then            
  STR0="$1"
else            
  STR0="$$"
fi
POS=2  # Starting from position 2 in the string.
LEN=8  # Extract eight characters.
STR1=$( echo "$STR0" | openssl md5 )
RANDSTRING="${STR1:$POS:$LEN}"

# Grab the contents of https://api.wordpress.org/secret-key/1.1/salt/
#SALT="$(curl -L https://api.wordpress.org/secret-key/1.1/salt)"

# Do some find/replace in the wp-config.php
$GSED -i "s/{{tableprefix}}/${RANDSTRING}/g" wp-config.php
$GSED -i "s/{{projectname}}/${PROJECTNAME}/g" wp-config.php
$GSED -i "s/{{localdbpass}}/${MYSQL_PASS}/g" wp-config.php
$GSED -i "s/{{remoteuser}}/${REMOTE_USER}/g" wp-config.php
$GSED -i "s/{{remotedbpass}}/${REMOTE_DB_PASS}/g" wp-config.php
$GSED -i "s/{{remotehost}}/${REMOTE_HOST}/g" wp-config.php
#$GSED -i "s/{{generatedsalt}}/${SALT}/g" wp-config.php			#Not Working currently

echo -e $CYAN"Finished with the wp-config.php, double check it"$WHITE


###########################################
## Create deploy scripts with Capistrano ##
###########################################
DEPLOY=
while [ -z $DEPLOY ]
do 
	echo -e -n $QMARK'[?] '$Q'Want to use Capistrano for deployment? ' $YN'(y/n) '
	read DEPLOY
done

if [[ "${DEPLOY}" =~ ^[Yy]$ ]]
	then

		mkdir $DEPLOY_DIR/$PROJECTNAME
		cp -R $THIS_DIR/capistrano/ $DEPLOY_DIR/$PROJECTNAME
		cd $DEPLOY_DIR/$PROJECTNAME/config

		# Do some find/replace in the templates
		$GSED -i "s/{{githubuser}}/${GITHUB_USER}/g" deploy.rb
		$GSED -i "s/{{projectname}}/${PROJECTNAME}/g" deploy.rb
		$GSED -i "s/{{remoteuser}}/${REMOTE_USER}/g" deploy/staging.rb
		$GSED -i "s/{{remotehost}}/${REMOTE_HOST}/g" deploy/staging.rb
		$GSED -i "s/{{domain}}/${PUBLIC_URL}/g" deploy/staging.rb
		$GSED -i "s/{{remoteuser}}/${REMOTE_USER}/g" deploy/production.rb
		$GSED -i "s/{{remotehost}}/${REMOTE_HOST}/g" deploy/production.rb
		$GSED -i "s/{{domain}}/${PUBLIC_URL}/g" deploy/production.rb
fi

################################################
## Create Amazon S3 Backup system for project ##
################################################
S3BACKUPS=
while [ -z $S3BACKUPS ]
do 
	echo -e -n $QMARK'[?] '$Q'Want to create an Amazon S3 backup system? ' $YN'(y/n) '
	read S3BACKUPS
done

if [[ "${S3BACKUPS}" =~ ^[Yy]$ ]]
	then
		# Create new bucket on Amazon S3 (requires s3cmd tools - s3tools.org/repositories)
		s3cmd mb s3://houndstooth-${PROJECTNAME}

		# Change over to project directory
		cd ${SITES_DIR}/${PROJECTNAME}

		# Clone WordPress S3 Backups script
		git clone git@github.com:HoundstoothSTL/wordpress-s3-backup.git wordpress-s3-backup
		cd wordpress-s3-backup
		rm -rf .git

		# Do some find/replace in the template
		$GSED -i "s/{{projectname}}/${PROJECTNAME}/g" wps3backup.sh
		$GSED -i "s/{{mysqluser}}/${REMOTE_USER}/g" wps3backup.sh
		$GSED -i "s/{{mysqlpass}}/${REMOTE_DB_PASS}/g" wps3backup.sh
		$GSED -i "s/{{mysqldb}}/${PROJECTNAME}_prod/g" wps3backup.sh
		$GSED -i "s/{{s3bucket}}/${PROJECTNAME}/g" wps3backup.sh
		$GSED -i "s/{{user}}/${REMOTE_USER}/g" wps3backup.sh
		$GSED -i "s/{{domain}}/${PUBLIC_URL}/g" wps3backup.sh

		echo -e $CYAN'Finished with the wordpress s3 backup setup' 
		echo -e $CYAN'You might want to double check the' $LIGHTRED'wps3backup.sh file. ' $TXTRST
fi

# Restart Apache
echo "Checking and restarting Apache"
CHECK_APACHE="$(ps ax | grep -v grep | grep -c httpd)"
if [ $CHECK_APACHE -gt 0 ]
then
	sudo $APACHECTL restart
    if ps ax | grep -v grep | grep httpd > /dev/null
	then
    	echo -e "Apache has been restarted" $LIGHTGREEN"		[OK]"
    fi
fi

# Open Chrome and setup WordPress
$OPEN -a "/Applications/Google Chrome.app" "http://${DOMAIN}/site/wp-admin"
say process is finished
say titee sprinkles