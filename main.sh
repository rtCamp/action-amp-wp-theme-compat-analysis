#!/usr/bin/env bash

set -e

######################################################
######################## VARS ########################
SITE_NAME='amp-wp-theme-compat-analysis.site'
SITE_ROOT="/var/www/$SITE_NAME/htdocs"
SITE_URL="http://$SITE_NAME/"

theme_root="$SITE_ROOT/wp-content/theme-directories/wp-themes"
results_root="$SITE_ROOT/results/theme-directories"
readme_path="$SITE_ROOT/README.md"
THEME_DIRS=()

URI=https://api.github.com
API_VERSION=v3
API_HEADER="Accept: application/vnd.github.${API_VERSION}+json; application/vnd.github.antiope-preview+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
PR_NUMBER=$(jq -r .number "$GITHUB_EVENT_PATH")
#####################################################

# Start required services for site creation
function start_services() {

    echo "Starting services"
    git config --global user.email "nobody@example.com"
    git config --global user.name "nobody"
    rm /etc/nginx/conf.d/stub_status.conf /etc/nginx/sites-available/22222 /etc/nginx/sites-enabled/22222
    rm -rf /var/www/22222
    wo stack start --nginx --mysql --php74
    wo stack status --nginx --mysql --php74
}

# Create, setup and populate WP site with data
function create_and_configure_site () {

    wo site create $SITE_NAME --wp --php74
    cd $SITE_ROOT
    rsync -av /wp-content/ $SITE_ROOT/wp-content/
    echo "127.0.0.1 $SITE_NAME" >> /etc/hosts

    wp rewrite structure "/%year%/%monthnum%/%day%/%postname%/" --hard --allow-root
    wp plugin install --activate amp --allow-root
    wp option update --json amp-options '{"theme_support":"standard"}' --allow-root
    wp plugin install --activate wordpress-importer --allow-root
    wp plugin install --activate block-unit-test --allow-root

    if [[ ! -f themeunittestdata.wordpress.xml ]]; then
        wget https://raw.githubusercontent.com/WPTRT/theme-unit-test/master/themeunittestdata.wordpress.xml
    fi

    if [[ 0 == $(wp menu list --format=count --allow-root) ]]; then
        wp import --quiet --authors=create themeunittestdata.wordpress.xml --allow-root
    fi

    if [[ 0 == $(wp post list --post_type=attachment --post_name=accelerated-mobile-pages-is-now-just-amp --format=count --allow-root) ]]; then
        wget https://blog.amp.dev/wp-content/uploads/2019/04/only_amp.mp4
        wp media import --title="Accelerated Mobile Pages is now just AMP" only_amp.mp4 --allow-root
        rm only_amp.mp4
    fi

    wp create-monster-post --allow-root
    wp populate-initial-widgets --allow-root
}

# Get the list of themes being updated in PR.
function get_themes_in_pr() {

    echo "Fetching theme list involved in PR"
    FILE_LIST=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files")
    FILES=$(echo $FILE_LIST | jq -r '.[] | .filename')
 
    DIRS_IN_PR=()

    for file in $FILES; do
        DIRS_IN_PR+=($(echo "$file" | cut -d "/" -f1))
    done

    UNIQUE_DIRS=($(echo "${DIRS_IN_PR[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Check if the dir is actually a theme dir or not.
    for dir in "${UNIQUE_DIRS[@]}"; do
        if [[ -f "$WORKSPACE/$dir/style.css" ]]; then
            THEME_DIRS+=($dir)
        fi
    done

}

# Sync themes being updates in PR to the theme root for analysis.
function sync_pr_themes_to_theme_root() {

    cd $SITE_ROOT
    mkdir -p $theme_root

    # Sync theme dirs in PR to theme root for analysis.
    for theme in "${THEME_DIRS[@]}"; do
        rsync -azh "$WORKSPACE/$theme" "$theme_root/"
    done
}

# Run amp validation checks and gather the data in results_root.
function check_themes() {

    theme=$1
    if [ -z "$theme" ]; then
        echo "Missing theme arg."
        exit 1
    fi

    directory=$2
    if [ -z "$directory" ]; then
        echo "Missing directory arg."
        exit 1
    fi

    if [ -e "$results_root/$directory/$theme" ]; then
        rm -r "$results_root/$directory/$theme"
    fi

    mkdir -p /tmp/pending-theme
    cd $SITE_ROOT
    wp --skip-plugins --skip-themes --allow-root theme activate "$theme"

    wp plugin activate --allow-root populate-widget-areas populate-nav-menu-locations
    monster_post_url=$(wp --skip-plugins --skip-themes --allow-root post list --post_type=post --name=monster --field=url | tr -d '\t \r\n')
    curl -m 30 -fsk "$monster_post_url" > "/tmp/pending-theme/monster.html"
    wp amp validation check-url --allow-root "$monster_post_url" > "/tmp/pending-theme/monster.json"

    wp plugin deactivate populate-widget-areas populate-nav-menu-locations --allow-root
    hello_world_post_url=$(wp --skip-plugins --skip-themes --allow-root post list --post_type=post --name=hello-world --field=url | tr -d '\t \r\n')
    curl -m 30 -fsk "$hello_world_post_url" > "/tmp/pending-theme/hello-world.html"
    wp amp validation check-url "$hello_world_post_url" --allow-root > "/tmp/pending-theme/hello-world.json"

    mkdir -p "$results_root/$directory/$theme"
    mv /tmp/pending-theme/* "$results_root/$directory/$theme"
}

# Loop through theme_root and analyze all of them.
function setup_and_check_themes() {

    theme_count=$(ls "$theme_root" | wc -l | sed 's/ //g')

    for theme in $(ls "$theme_root"); do
        if [[ ! -d "$theme_root/$theme" ]]; then
            continue
        fi

        echo $theme
        i=$((i+1))

        if [[ -e "$results_root/$theme" ]]; then
            echo "Results already obtained for theme: $theme"
            continue
        fi

        echo "## $theme ($i of $theme_count)"
            cp -r "$theme_root/$theme" "$SITE_ROOT/wp-content/themes/$theme"

        # Ensure the parent theme is installed (sometimes auto-installed other times not?)
        parent_theme=$(wp get-parent-theme "$theme" --allow-root)
        if [[ ! -z "$parent_theme" ]]; then
            rsync -azh "$WORKSPACE/$parent_theme" "$SITE_ROOT/wp-content/themes/"
        fi

        check_themes "$theme" "wp-themes" || echo "Failed to check theme"

        # Clean out themes directory.
        rm -R $SITE_ROOT/wp-content/themes/*
        echo ''
    done
}

# Generate readme on readme_path from all the result data.
function generate_readme() {

    context=$1
    if [[ -z "$context" ]]; then
        echo "Missing context arg."
        exit 1
    fi

    cd $SITE_ROOT

    echo "## [$context] AMP WordPress Theme Compatibility" >> $readme_path
    [[ "$context" == "PR" ]] && echo 'What follows are the fidings of theme compatibility with the [official AMP plugin](https://github.com/ampproject/amp-wp).' >> $readme_path
    echo '' >> $readme_path

    echo "### Light Page" >> $readme_path
    echo '' >> $readme_path
    wp --allow-root --quiet gather-stats hello-world >> $readme_path
    echo '' >> $readme_path

    echo "### Heavy Page" >> $readme_path
    echo '' >> $readme_path
    wp --allow-root --quiet gather-stats monster >> $readme_path
}

# Delete a comment generated by this action if it is already there.
# We do not want to flood PR discussion with comments from the action.
# Only the latest comment with updated analysis should be there. 
delete_comment_if_exists() {

	# Get all the comments for the pull request.
	body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments")

	comments=$(echo "$body" | jq -r '.[] | {id: .id, body: .body} | @base64')

	for c in $comments; do
		comment="$(echo "$c" | base64 --decode)"
		id=$(echo "$comment" | jq -r '.id')
		b=$(echo "$comment" | jq -r '.body')

		if [[ "$b" == *"AMP WordPress Theme Compatibility"* ]]; then
			# We have found our comment.
			# Delete it.

			echo "Deleting old comment ID: $id"
			curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" -X DELETE "${URI}/repos/${GITHUB_REPOSITORY}/issues/comments/${id}" > /dev/null
		fi
	done
}

# Format and post the data generated from the action as comment in PR. 
post_amp_compat_data() {

	sed -i '/>/d' $readme_path
	sed -e 's/$/\\n/' -i $readme_path
	echo '\n' >> $readme_path
	echo '{"body":"'"$(cat $readme_path)"'"}' > comment.json

	curl -sSL -H "${AUTH_HEADER}" \
		-H "${API_HEADER}" \
		-H "Content-Type: application/json" \
		-X POST "${URI}/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
		--data @comment.json > /dev/null
}

# Cleanup theme and result root.
function cleanup() {

    rm -rf $theme_root $results_root
}

function main() {

    # generate PR analysis first
    WORKSPACE="$GITHUB_WORKSPACE/main"
    start_services
    create_and_configure_site
    get_themes_in_pr
    sync_pr_themes_to_theme_root
    setup_and_check_themes
    generate_readme "PR"
    cleanup

    # Generate base branch analysis
    WORKSPACE="$GITHUB_WORKSPACE/base"
    sync_pr_themes_to_theme_root
    setup_and_check_themes
    generate_readme "Base Branch"

    # Post the data as a comment
    delete_comment_if_exists
    post_amp_compat_data
}

main
