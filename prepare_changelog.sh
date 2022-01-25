#!/bin/bash

#
# Prepare change log clones the following repositories and creates change log since latest tag
# "Ant-Media-Server"
# "Ant-Media-Enterprise"
# "ManagementConsole_AngularApp"
# "StreamApp"
# "Ant-Media-Server-Parent"

# Usage
# ./prepare_change_log [BRANCH_NAME] [TAG]
#
# BRANCH_NAME is the branch where change log will be created. It's optional.
# TAG is the tag where change log will be created since then. It's optional. If not specified, it will create the changelog
# since the last tag
#
# Important: To get MR from gitlab, there should be environment variable(GITLAB_TOKEN) exported with valid token
# To get PR from github, there should be environment variable(GITHUB_TOKEN) exported with valid token
# 



BRANCH_NAME=$1
TAG=$2
CHANGE_LOG=`pwd`/changelog.html

get_change_log() 
{
	GIT_URL=$1
	FOLDER=$2
	PULL_REQUEST_BASE_URL=$3

	if [ $(git ls-remote $GIT_URL $BRANCH_NAME  | wc -l) == "1" ];  
  then 
      echo " $BRANCH_NAME branch found";  
      git clone --depth=200 -b $BRANCH_NAME $GIT_URL $FOLDER;  
        
  else
      echo "branch not found. Checking out master"; 
      git clone --depth=200 $GIT_URL $FOLDER;  
  fi

  cd $FOLDER
	if [ ! -n "$TAG" ]; then
	  echo "TAG parameter not supplied.";
	  TAG=`git tag --sort=-creatordate | head -n 1`;
	fi

  DATE_OF_THE_TAG=`git log -1 --date=iso-strict --pretty=format:%ad $TAG`

  echo "<h3>$FOLDER</h3>" >> $CHANGE_LOG
  gh pr list --state merged --search "closed:>$DATE_OF_THE_TAG" -L 1000 --json title,body,number --template "{{range .}} <li> <a href='$PULL_REQUEST_BASE_URL/pull/{{.number}}'>{{.number}}</a> {{.title}} - <a href='{{.body}}'>{{.body}}</a></li>{{end}}" >> $CHANGE_LOG

  cd ..
 
}

rm -f $CHANGE_LOG
touch $CHANGE_LOG

#get Ant Media Server
export GH_REPO=ant-media/Ant-Media-Server
export GH_HOST=github.com
get_change_log https://github.com/ant-media/Ant-Media-Server.git Ant-Media-Server https://github.com/ant-media/Ant-Media-Server

#get Ant Media Server Enterprise log
if [ ! -n "$TAG" ]; then
  echo "TAG parameter not supplied.";
  TAG=`git tag --sort=-creatordate | head -n 1`;
fi
echo "<h3>Ant-Media-Enterprise</h3>" >> $CHANGE_LOG

DATE_OF_THE_TAG=`git log -1 --date=iso-strict --pretty=format:%ad $TAG`
curl --location --request GET "https://gitlab.com/api/v4/projects/5032874/merge_requests?state=merged&view=simple&per_page=100&updated_after=$DATE_OF_THE_TAG" --header "Authorization: Bearer $GITLAB_TOKEN" 2>/dev/null  | jq -r ' .[] | "<li>\(.title)- <a href=\(.description)) >\(.description)</a></li>"' >> $CHANGE_LOG

# "StreamApp"
export GH_REPO=ant-media/StreamApp
get_change_log https://github.com/ant-media/StreamApp.git StreamApp https://github.com/ant-media/StreamApp

# "Ant-Media-Server-Parent"
export GH_REPO=ant-media/ant-media-server-parent
get_change_log https://github.com/ant-media/ant-media-server-parent.git Ant-Media-Server-Parent https://github.com/ant-media/ant-media-server-parent

# "ManagementConsole_AngularApp"
export GH_REPO=ant-media/ManagementConsole_AngularApp
get_change_log https://github.com/ant-media/ManagementConsole_AngularApp.git ManagementConsole_AngularApp https://github.com/ant-media/ManagementConsole_AngularApp
