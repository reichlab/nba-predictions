#!/bin/sh

setup_git() {
  git config --global user.email "git@github.com"
  git config --global user.name "Github Actions CI"
}

commit_website_files() {
  echo "Commiting files..."
  git add .
  git commit --message "Github Actions build: $GITHUB_RUN_NUMBER"
}

upload_files() {
  echo "Uploading files..."
  git fetch
  git pull --rebase https://${GH_TOKEN}@github.com/reichlab/nba-predictions.git
  git push https://${GH_TOKEN}@github.com/reichlab/nba-predictions.git HEAD:main
  echo "pushed to github"
}

setup_git
commit_website_files
upload_files