# DIDOW

## Requirements
- Docker

## Create root sites project folder
1. Create a folder to use as root of all the sites you is going to create, for example `docker-didow`.
All the sites created will be stored in `/sites/` folder creating the following folder's structure `didow-docker/sites/PROJECT_NAME`.
2. Create `_didow` folder to use for didow repository.

## Download the repository
https://github.com/DinkumInteractive/didow

## Build Docker Image
Inside `docker-didow/_didow` folder, run the following command to generate the new docker image:

`$ docker build -f Dockerfile -t didow/wordpress:5.8.0-php7.4-apache-xdebug-unit6.0 .`

## Create a new project
Create a new WordPress project. Inside root sites folder run the create command.

*Command:*
`./_didow/didow-wp.sh create PROJECT_NAME`

### Project access
Once the process is finished you can access to the site project using the url format `PROJECT_NAME.TLD` where default `TLD` is `di-local.com`.
So if you create a project `my_site` the default url will be `my_site.di-local.com`.
If you want to use a different `TLD` you can edit the `_conf/tld.conf` file and setup your own.

### Install ssl cert in local keys and make it always trusted
1. Open Keichain Access App.
2. In System's Keychains, in the Categories, select Certificates and Install SSL cert .crt file.
3. Double click in the certificate added and then in Trusted tab, Give "Trust always" permission to the installed Cert.
4. Close the window to be asked to store the changes.

## Migrate an existing project
If you are trying to install a site that already exists, run migrate process.
During project delete you have the options to:
- Migrate database: you must to provide a dump SQL file to import into the database. For existing tables, this will overwrite all the info stored in current database.
- Migrate domain: you need to insert the OLD domain name that will be replaced by the local domain. You will be asked for different domain names you want to replace until you left it empty to continue.
- Inster New Admin User: in case you don't have, or don't recall the administrator access you have the option to create a new user providing name and email only. Password will be generated automatically and displayed in the terminal after user is created.

*Command:*
`./_didow/didow-wp.sh migrate PROJECT_NAME`

## Delete a project
During project delete you have the options to:
- Deleting project containers: this will stop and then remove all the containers related to this project along with their volumes, all database infomation will be lost. Also hosts declaration and SSL certificates will be removed.
- Deleting project files: this will delete all project folders.

*Command:*
`./_didow/didow-wp.sh delete PROJECT_NAME`

 
