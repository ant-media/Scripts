#!/bin/bash

#
# Prepare change log clones the following repositories and creates change log since latest tag
# "Ant-Media-Server"
# "Ant-Media-Enterprise"
# "Ant-Media-Server-Common"
# "ManagementConsole_WebApp"
# "ManagementConsole_AngularApp"
# "StreamApp"
# "Ant-Media-Server-Parent"
# "Ant-Media-Server-Service"

# Usage
# ./prepare_change_log [BRANCH_NAME] [TAG]
#
# BRANCH_NAME is the branch where change log will be created. It's optional.
# TAG is the tag where change log will be created since then. It's optional. If not specified, it will create the changelog
# since the last tag


BRANCH_NAME=$1
TAG=$2
CHANGE_LOG=`pwd`/changelog.html

get_change_log() 
{
	GIT_URL=$1
	FOLDER=$2
	
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

  echo "$FOLDER" >> $CHANGE_LOG
  git log --no-merges --pretty=format:"<li> <a href='http://github.com/ant-media/$FOLDER/commit/%H'>%h</a> %s - %ci</li>" --reverse $TAG..HEAD >> $CHANGE_LOG

  cd ..
 
}

rm -f $CHANGE_LOG
touch $CHANGE_LOG
echo "<style>
li , body {
  font-family: sans-serif;
  line-height: 35px;
}
</style>" >> $CHANGE_LOG

#get Ant Media Server
get_change_log https://github.com/ant-media/Ant-Media-Server.git Ant-Media-Server

#get Ant Media Server Enterprise log
if [ ! -n "$TAG" ]; then
  echo "TAG parameter not supplied.";
  TAG=`git tag --sort=-creatordate | head -n 1`;
fi
echo "Ant-Media-Enterprise" >> $CHANGE_LOG
git log --no-merges --pretty=format:"<li>%h - %s - %ci</li>"  $TAG..HEAD --reverse >> $CHANGE_LOG

# "Ant-Media-Server-Common"
get_change_log https://github.com/ant-media/Ant-Media-Server-Common.git Ant-Media-Server-Common

# "StreamApp"
get_change_log https://github.com/ant-media/StreamApp.git StreamApp

# "Ant-Media-Server-Parent"
get_change_log https://github.com/ant-media/ant-media-server-parent.git Ant-Media-Server-Parent

# "ManagementConsole_WebApp"
get_change_log https://github.com/ant-media/ManagementConsole_WebApp.git ManagementConsole_WebApp

# "ManagementConsole_AngularApp"
get_change_log https://github.com/ant-media/ManagementConsole_AngularApp.git ManagementConsole_AngularApp

# "Ant-Media-Server-Service"
get_change_log https://github.com/ant-media/Ant-Media-Server-Service.git Ant-Media-Server-Service



