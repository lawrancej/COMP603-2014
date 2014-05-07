#!/bin/bash

# The instructor's Github username
GITHUB_INSTRUCTOR=lawrancej
# The repository to clone as upstream (NO SPACES)
REPO=COMP603-2014

# Utilities
# ---------------------------------------------------------------------

next_step() {
    read -p "Press enter to continue." < /dev/tty
}

# Cross platform file open
file_open() {
    case $OSTYPE in
        msys | cygwin ) echo "Opening $1"; sleep 1; start "$1" ;;
        linux* ) echo "Opening $1"; sleep 1; gnome-open "$1" ;;
        darwin* ) echo "Opening $1"; sleep 1; open "$1" ;;
        *) echo "Please open $1" ;;
    esac
    next_step
}

# Git functions
# ---------------------------------------------------------------------

# Ask user to set a key in ~/.gitconfig if it's not already set.
# $1 is the key
# $2 is the prompt
set_key() {
    value=$(git config --global $1)
    while [ -z "$value" ]; do
        read -p "$2: " value < /dev/tty
        git config --global $1 "$value"
    done
}

configure_git() {
    set_key user.name "Enter your full name (e.g., Jane Smith)"
    set_key user.email "Enter your school email address (e.g., smithj@wit.edu)"
}

# SSH functions
# ---------------------------------------------------------------------

generate_key() {
    while [[ ! -f ~/.ssh/id_rsa.pub ]]; do
        echo "Push enter to accept defaults. Remember your passphrase (or just press enter)."
        ssh-keygen -t rsa < /dev/tty
    done
}

copy_key_to_clipboard() {
    case $OSTYPE in
        msys | cygwin ) echo "Copied your public key to clipboard."; cat ~/.ssh/id_rsa.pub > /dev/clipboard ;;
        linux* ) echo "Copied your public key to clipboard."; cat ~/.ssh/id_rsa.pub | xclip -selection clipboard ;;
        darwin* ) echo "Copied your public key to clipboard."; cat ~/.ssh/id_rsa.pub | pbcopy ;;
        * ) echo "Copy your public key (below) to the clipboard:"; cat ~/.ssh/id_rsa.pub ;;
    esac
}

# Github functions
# ---------------------------------------------------------------------

github_join() {
    if [ -z $(git config --global github.login) ]; then
        read -p "Do you have a Github account [y/N]? " yn < /dev/tty
        # Let's assume that they don't by default
        if [[ $yn != [Yy]* ]]; then
            printf "Join Github using your school email address. "
            sleep 1
            file_open "https://github.com/join"
            echo "Open your school email inbox and verify your email with Github."
            sleep 2
            next_step
        fi
    fi
}

# Wow, it's complicated
# Sets $github_login and generates ~/.token with authentication token
github_authenticate() {
    if [[ ! -f ~/.token ]]; then
        set_key github.login "Enter your Github username (e.g., smithj)"
        github_login=$(git config --global github.login)
        token="HTTP/1.1 401 Unauthorized"
        code=''
        password=''
        while [[ ! -z $(echo $token | grep "HTTP/1.1 401 Unauthorized" ) ]]; do
            if [[ -z "$password" ]]; then
                read -s -p "Enter Github password: " password < /dev/tty
            fi
            token=$(curl -i -u $github_login:$password -H "X-GitHub-OTP: $code" -d '{"scopes": ["repo", "public_repo", "user", "write:public_key"], "note": "starterupper-script"}' https://api.github.com/authorizations 2> /dev/null)
            echo
            if [[ ! -z $(echo $token | grep "Bad credential") ]]; then
                echo "Incorrect password. Please wait a moment."
                password=''
                sleep 3
            fi
            if [[ ! -z $(echo $token | grep "two-factor" ) ]]; then
                read -s -p "Enter Github two-factor authentication code: " code < /dev/tty
            fi
        done
        if [[ ! -z $(echo $token | grep "HTTP/1.1 201" ) ]]; then
            token=$(echo $token | tr '"' '\n' | grep -E '[0-9a-f]{40}')
            echo $token > ~/.token
            echo "Authenticated!"
        else
            echo "Sorry, try again later."
            exit
        fi
    fi
    # Set this variable in case we were interrupted unexpectedly
    github_login=$(git config --global github.login)
}

github_get_discount() {
    echo "Request an individual student discount. "
    sleep 1
    file_open "https://education.github.com/discount_requests/new"
}

github_share_key() {
    echo "Sharing public key..."
    curl -i -H "Authorization: token $(cat ~/.token)" -d "{\"title\": \"$(hostname)\", \"key\": \"$(cat ~/.ssh/id_rsa.pub)\"}" https://api.github.com/user/keys 2> /dev/null > /dev/null
}

github_set_name() {
    echo "Updating Github profile information..."
    curl --request PATCH -H "Authorization: token $(cat ~/.token)" -d "{\"name\": \"$(git config --global user.name)\"}" https://api.github.com/user 2> /dev/null > /dev/null
}

github_setup_ssh() {
    ssh_test=$(ssh git@github.com 2>&1)
    if [[ -z $(echo $ssh_test | grep $github_login) ]]; then
        generate_key
        github_share_key
    fi
}

github_create_private_repo() {
    echo "Creating/checking private repository on Github..."
    curl -H "Authorization: token $(cat ~/.token)" -d "{\"name\": \"$REPO\", \"private\": true}" https://api.github.com/user/repos 2> /dev/null > /dev/null    
}

github_add_collaborator() {
    echo "Adding $1 as a collaborator..."
    curl --request PUT -H "Authorization: token $(cat ~/.token)" -d "" https://api.github.com/repos/$github_login/$REPO/collaborators/$1 2> /dev/null > /dev/null
}

github_user() {
    curl -H "Authorization: token $(cat ~/.token)" https://api.github.com/user 2> /dev/null
}

github_setup() {
    github_join
    github_authenticate
    github_get_discount
    github_set_name
    github_setup_ssh
    github_create_private_repo
    github_add_collaborator $GITHUB_INSTRUCTOR
    setup_repo
}

setup_repo() {
    echo "Configuring repository $REPO..."
    cd ~
    if [ ! -d $REPO ]; then
        git clone https://github.com/$GITHUB_INSTRUCTOR/$REPO.git
        file_open $REPO
        pushd $REPO
        git remote rename origin upstream
        git remote add origin git@github.com:$github_login/$REPO.git
        popd
    fi
    cd $REPO
    git push origin master
    result=$(echo $?)
    if [[ $result != 0 ]]; then
        echo "Your network connection has blocked SSH. Sorry"
        echo "Failed"
    else
        file_open "https://github.com/$github_login/$REPO"
        echo "Done"
    fi
}

github_revoke() {
    echo "Delete starterupper-script under Personal access tokens"
    file_open "https://github.com/settings/applications"
}

# Clean up everything but the repo (BEWARE!)
clean() {
    github_revoke
    git config --global --unset user.name
    git config --global --unset user.email
    git config --global --unset github.login
    rm -f ~/.ssh/id_rsa*
    rm -f ~/.token
}

if [ $# == 0 ]; then
    configure_git
    github_setup
elif [[ $1 == "clean" ]]; then
    clean
fi

# github_user
