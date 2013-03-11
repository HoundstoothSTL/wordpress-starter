#!/bin/bash

# Build version 1.0.0

LOCAL_UPLOADS_DIR=""
STAGING_UPLOADS_DIR=""
PRODUCTION_UPLOADS_DIR=""

rsync -avz /Users/rwbennet/Dropbox/Houndstooth/Sites/intelispend/site/wp-content/uploads/ deploy@207.223.251.90:/var/www/domains/intelispend.com/staging/wordpress/shared/uploads/