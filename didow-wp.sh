#!/bin/bash

# A Dinkum Interactive WordPress Docker Environment for MAC
# Copyright (C) 2020 Guillermo Tenaschuk guillermo@dinkuminteractive.com

# Project based on https://github.com/johnrom/nimble

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Script name
command=$0

# Define script source
source="$PWD/_didow/didow-wp.sh"
source_root="$PWD/_didow"

# Check that we're running in docker root directory
if [[ ! -f $source ]]; then
    echo "This command must be run from the docker root directory. Please navigate there to use Nimble."
    exit 1
fi

# Define the Top Level Domain
tld="$(<$source_root/_conf/tld.conf)"

if [[ -z "$tld" ]]; then
    tld="di-local.com"
fi

# Define site root folder
site_root="$(<$source_root/_conf/site_root.conf)"

if [[ -z "$site_root" ]]; then
    site_root="$PWD/sites"
fi

# Define SSL certificate folder
certs_root="$site_root/_conf/certs"

help(){
	echo "Create new project:"
	echo "Usage: $command create {PROJECT_NAME}"

	echo "Delete project:"
	echo "Usage: $command delete {PROJECT_NAME}"

	echo "Migrate project:"
	echo "Usage: $command migrate {PROJECT_NAME}"

	echo "Create user:"
	echo "Usage: $command create_user {PROJECT_NAME}"

	echo "Project Info:"
	echo "Usage: $command info {PROJECT_NAME}"
}

args(){
    #!/bin/bash
    # Use -gt 1 to consume two arguments per pass in the loop (e.g. each
    # argument has a corresponding value to go with it).
    # Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
    # some arguments don't have a corresponding value to go with it such
    # as in the --default example).
    # note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
    local i=1

    while [[ i -le "$#" ]]
    do
        local key="${!i}"
        local value_index=$(($i+1))
        local value="${!value_index}"

        case $key in
            -t|--template)
                template="$value"

                set -- "${@:1:i-1}" "${@:i+2}"
            ;;
            *)
                # unknown option
            ;;
        esac

        i=$(($i+1))
    done

    argies="$@"
}

# nice yes/no function
confirm() {
    # https://djm.me/ask
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

create(){

    # requires project name
    if [[ -z "$1" ]]; then
        help
        return
    fi

    local project="$1"
    local site_dir="$site_root/$project"
    local www_dir="$site_root/$project/html"

	create_nginx_proxy

    # create directories
    #
    if [ -d "$site_dir" ]; then
        echo "Error: Folder already exists for project: $project. Exiting!"
        exit 1
    fi

    echo "creating project directory: $www_dir"

    mkdir -p $www_dir

	# ip=$(ifconfig | grep "inet " | grep -Fv 127.0.0.1 | awk '{print $2}')
	ip="host.docker.internal"
	remoteport="9000"

	# Ask the question - use /dev/tty in case stdin is redirected from somewhere else
	read -e -p "Table Prefix: Press enter to use wp_ or write your table prefix if it is different: " tableprefix </dev/tty

    # Default?
	if [[ -z "$tableprefix" ]]; then
		tableprefix="wp_"
	fi

    local dev_template=$(<$source_root/docker-compose.yml)

    dev_template=${dev_template//PROJECT/$project}
    dev_template=${dev_template//TLD/$tld}
    dev_template=${dev_template//CERTROOT/$certs_root}
    dev_template=${dev_template//REMOTEHOST/$ip}
    dev_template=${dev_template//REMOTEPORT/$remoteport}
    dev_template=${dev_template//WP_TABLE_PREFIX/$tableprefix}

    echo "$dev_template" > "$site_dir/docker-compose.yml"

    init $project

	# Go to the site html folder created.
	cd $www_dir
	echo "You can access to the site via http or https using the url: $project.$tld"
}

delete(){
    # requires project name
    if [[ -z "$1" ]]; then
        help
        return
    fi

    local project="$1"
    local site_dir="$site_root/$project"

    # check directories
    #
    if [ ! -d "$site_dir" ]; then
        echo "Error: Project Folder does not exists: $project. Exiting!"
        exit 1
    fi

	# Stop and remove containers and volumes associated to them
	if confirm " Stop and Delete containers and volumes for $project? This is irreversible!" N; then
        echo "Deleting $project containers and volumes."
		# $site_dir/docker compose down -v >& /dev/null
		cd $site_dir
		docker compose down -v
		for i in {1..5}
		do
			printf '.'
			sleep 1
		done
		cd $source_root

		echo "Deleting $project certificates."
		rm -f $certs_root/"$project.$tld.key"
		rm -f $certs_root/"$project.$tld.crt"
	fi

    if confirm "Delete Project Files for $project? You could lose work! This is irreversible!" N; then
        echo "Deleting $project files."
		rm -rf $site_dir
    fi
}

create_nginx_proxy(){
	local project="_nginx_proxy"
    local site_dir="$site_root/$project"

    # create directories
    if [ -d "$site_dir" ]; then
        echo "NGINX Folder already exists. Continuing creating the project!"
        return
    fi

	echo "creating project directory: $site_dir"

    mkdir -p $site_dir

	local dev_template=$(<$source_root/docker-compose-nginx-proxy.yml)

    dev_template=${dev_template//CERTROOT/$certs_root}

    echo "$dev_template" > "$site_dir/docker-compose.yml"

	cd $site_dir

	# starting docker compose in detached mode
    docker compose up -d

	cd $source_root
}

init() {

    if [[ -z "$1" ]]; then
        help
        return 1
    fi

    local project="$1"
	local www_dir="$site_root/$project/html"

    # Remove this project from hosts file in case it already exists
	rmhosts $project
	# Add this project to the hosts file
	hosts $project

	# Create Certificates
	cert $project

	# Copy config files
	cp -R "$source_root"/.vscode "$www_dir"
	cp -R "$source_root"/.editorconfig "$www_dir"
	cp -R "$source_root"/phpcs.xml "$www_dir"

	# ignore project directories
	cp "$source_root"/.gitignore.dist "$www_dir"/.gitignore

    echo "Starting containers"
	cd $www_dir

	# starting docker compose in detached mode
    docker compose up -d

	echo "Waiting until containters are ready."
	i=0
	code=null
	while [ $i -lt 60 ]
	do
		((i++))
		printf '.'
		code=$(curl -s -o /dev/null -I -w "%{http_code}" "http://$project.$tld")
		if [[ "$code" -eq "200" || "$code" -eq "302" ]]; then
			printf '\n'
			break
		fi
		sleep 1
	done
	echo "Containters are ready."

	if confirm "Do you want to migrate an existing site?"; then
		if [[ "$code" -eq "200" || "$code" -eq "302" ]]; then
			migrate $project
		else
			echo "Site is not responding, try running migrate command again or check your containers and configuration to confirm all is ok."
		fi
	fi
}

hosts() {
    # requires project name
    if [[ -z "$1" ]]; then
        help
        return
    fi

    local project=$1
    # check Git Bash hosts location
    local file="/etc/hosts"

    local ip="127.0.0.1"

    # Editing Hosts
    #
    echo "Adding $project.$tld to hosts file at $ip"
    echo "Adding phpmyadmin.$project.$tld to hosts file at $ip"
    echo "Adding webgrind.$project.$tld to hosts file at $ip"

    x=$(tail -c 1 "$file")

    if [ "$x" != "" ]
    then
        sudo -- sh -c "echo '' >> /etc/hosts";
    fi

	sudo -- sh -c "echo '' >> $file";
	sudo -- sh -c "echo '# ===== $project.$tld Domains =====' >> $file";
	sudo -- sh -c "echo '$ip   $project.$tld' >> $file";
	sudo -- sh -c "echo '$ip   phpmyadmin.$project.$tld' >> $file";
	sudo -- sh -c "echo '$ip   webgrind.$project.$tld' >> $file";
}

rmhosts() {

    # requires project name
    if [[ -z "$1" ]]; then
        help
        return
    fi

    local file="/etc/hosts"
    local project=$1
    local tab="$(printf '\t') "

    echo "Removing $project domains from $file"
    sudo grep -vE "\s((phpmyadmin|webgrind)\.)?$project\.$tld" "$file" > hosts.tmp && sudo cat hosts.tmp > "$file"

    rm hosts.tmp
}

cert() {

    if [[ -z "$1" ]]; then
        help
        return
    fi

	# create directories
    if [ ! -d "$certs_root" ]; then
		echo "creating certs directory: $certs_root"
        mkdir -p $certs_root
    fi

    local project=$1

	# Create SSL cert and key to be imported in your local keychain
    openssl req \
        -newkey rsa:2048 -nodes \
        -subj "/C=US/ST=Pennsylvania/L=Philadelphia/O=MyOrganization/CN=$project.$tld" \
        -keyout $certs_root/"$project.$tld.key" \
        -x509 -sha256 -days 365 -out $certs_root/"$project.$tld.crt" \
		-extensions EXT -config <( printf "[dn]\nCN=$project.$tld\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:$project.$tld\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
}

migrate() {
    local project=$1
	local reply
    if [[ -z $project ]];
    then
        echo "Usage: \$command migrate \$project"
        exit 1
    fi

	printf "\n ==== DB MIGRATION ==== \n"
	# Ask the question (not using "read -p" as it uses stderr not stdout)
	echo -n "Migrate database? Press (P) for Pantheon, (L) for local file or press enter to continue: "

	# Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
	read reply </dev/tty

	# Check if the reply is valid
	case "$reply" in
		P*|p*) migrate_pantheon_db $project ;;
		L*|l*) migrate_db $project ;;
	esac

	printf "\n ==== DOMAIN MIGRATION ==== \n"
	if confirm "Do you want to migrate domain?"; then
		migrate_domain $project
	fi

	printf "\n ==== ADMIN USER ==== \n"
	if confirm "Do you want to create a new Admin user?"; then
		create_user $project
	fi
	printf "\n ==== SITE ADDRESS ==== \n"
	echo "You can access to the site via http or https using the url: $project.$tld"
}

migrate_pantheon_db() {
	local project=$1
	local dump_file="$site_root/$project/database.sql"
	local dump_file_compressed="$dump_file.gz"
	if [[ -z $project ]];
    then
        echo "Project name required to migrate a database."
        return
    fi


	# Ask the question - use /dev/tty in case stdin is redirected from somewhere else
	read -e -p "Enter site and environment as 'MY_SITE.ENV': " site </dev/tty

	# Default?
	if [[ -z "$site" ]]; then
		echo "Site and ENV required to migrate a database."
		return 0
	fi

	if confirm "Do you want to create a new DB Backup in Pantheon?" N; then
		echo "Creating Pantheon DB Backup."
		terminus backup:create "$site" --element=db
	fi

	echo "Downloading Latest Pantheon DB Backup."
	terminus backup:get "$site" --element=db --to="$dump_file_compressed"
	echo "Downloading Pantheon DB backup as $dump_file_compressed."
	if [[ -f "$dump_file_compressed" ]]; then
		echo "Pantheon DB backup downloaded. Decompressing $dump_file_compressed as $dump_file."
		gunzip "$dump_file_compressed"
		echo "Restoring DB from $dump_file."
		migrate_db_run $project "$dump_file"
	else
		echo "Pantheon DB backup was not downloaded check if the file exists and if you have the right permissions."
		return
	fi
}

migrate_db() {
	local project=$1
	local dump_file
	if [[ -z $project ]];
    then
        echo "Project name required to migrate a database."
        return
    fi
	while true;
	do
		# Ask the question - use /dev/tty in case stdin is redirected from somewhere else
		read -e -p "Database Dump File full path [empty to continue without migration process]: " dump_file </dev/tty

		# Default?
		if [[ -z "$dump_file" ]]; then
			return 0
		elif [[ ! -f $dump_file ]]; then
			echo "Database Dump file doesn't exists, please enter a valid path or empty value to continue without migrating a database: "
		else
			break
		fi
	done
	migrate_db_run $project $dump_file
}

migrate_db_run() {
	local project=$1
	local dump_file=$2
	echo "docker exec -i $project _db mysql --init-command='SET SESSION FOREIGN_KEY_CHECKS=0;' -uroot -pwordpress wordpress < $dump_file"
	docker exec -i "$project"_db mysql --init-command="SET SESSION FOREIGN_KEY_CHECKS=0;" -uroot -pwordpress wordpress < "$dump_file"
}

migrate_domain() {
	local project=$1
    local url="$project.$tld"
    local remote
	if [[ -z $project ]];
    then
        echo "Project name required to migrate domains."
        return
    fi

    while true; do
        # Ask the question - use /dev/tty in case stdin is redirected from somewhere else
        read -e -p "Remote Domain [empty to continue, use www THEN non-www versions to replace by your local domain]: " remote </dev/tty

        # Default?
        if [[ -z "$remote" ]]; then
            return 0
        fi

        echo "Old Url: $remote"
        echo "New Url: $url"
        echo "docker exec -i $project /bin/bash -c wp search-replace $remote $url"

        docker exec -i "$project" /bin/bash -c "wp search-replace $remote $url"
    done
}

create_user() {
	local project=$1
    local username
	local useremail
	if [[ -z $project ]];
    then
        echo "Project name required to create a new user."
        return
    fi
	 # Ask the question - use /dev/tty in case stdin is redirected from somewhere else
	read -p "WP User Name: " username </dev/tty
	read -p "WP User Email: " useremail </dev/tty

	docker exec -i "$project" /bin/bash -c "wp user create $username $useremail --role='administrator'"
}

info() {
	local project=$1
	if [[ -z $project ]];
    then
        echo "Project name required to display information."
        return
    fi

	echo "URL: $project.$tld"
	echo "PHPMyAdmin: phpmyadmin.$project.$tld"
    echo "WWW Dir: $site_root/$project/html"
    echo "Database Dir: $site_root/$project/db_data"
    echo "Docker Compose File: $site_root/$project/docker-compose.yml"
	echo "Cert Key File: $certs_root/$project.$tld.key"
	echo "Cert CRT File: $certs_root/$project.$tld.crt"
}

if (! docker stats --no-stream > null ); then
	echo "Docker is required for this tool, please launch Docker and then try again."
	exit 1
fi

# Commands Allowed
if [[ $1 =~ ^(help|create|migrate|create_user|delete|info)$ ]]; then

    if [[ $1 = "bash" ]]; then
        set -- "bashitup" "${@:2}"
    fi

    args "$@"

    $argies
else
  help
fi

printf "\n ===== END OF THE STORY! ===== \n"
