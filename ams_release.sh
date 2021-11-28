#!/bin/bash
#Usage
#First parameter is the version name either release or snapshot works
#if it is release version, script create and checkout a branch, update version, commit, tag and push the script
# ./ams_release.sh 1.6.1
#if it is release version with branch parameter, script create & checkout a branch and push the 
#./ams_release.sh 1.6.1 branch
#if it is a snapshot version, it updates the version, commits and pushes . After that it should be merged with master
#./ams_release.sh 1.6.2-SNAPSHOT

#Future work: Deploying to maven central takes about 2-3 hours so that it blocks Ant-Media-Server to pass the test.
#another solution we may add sonatype as release repo

if [ -z "$1" ]; then
  echo "Please give the version as parameter"
  echo "Sample usage:"
  echo "$0  1.6.1  -> create & checkout the release branch, update version, commit, tag and push to the origin"
  echo "$0  1.6.1 branch -> create & checkout the release branch, don't update version, push to the origin "
  echo "$0  1.6.1-SNAPSHOT -> update the version, commit and push to the origin"
  exit 1
fi


check() {
  OUT=$1
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in releasing. Please check the log above"
    exit $OUT
  fi
}

#Creates a new branch, update version
#commit, tag and push
#### Update below script if the operation is done previously and re-executed again
update_version_and_push()
{
  NEW_VERSION=$1
  BRANCH_NAME=release/$NEW_VERSION
  TAG_NAME=ams-v$NEW_VERSION

  ALLOW_SNAPSHOT=""
  #create and checkout branch
  if [[ ! $NEW_VERSION =~ .*SNAPSHOT$ ]]; #if it is not a snapshot version
  then
	  echo "Checking out $BRANCH_NAME"
    if [ `git branch --list $BRANCH_NAME | wc -l` == "0" ]
    then
      echo "$BRANCH_NAME branch is being created."
      git branch $BRANCH_NAME
    fi
    git checkout $BRANCH_NAME
  else
    #if it is a snasphot version allow latest snapshot
    ALLOW_SNAPSHOT=-DallowSnapshots=true
  fi

  check $?


  CURRENT_DIR=`pwd`

  # Check the current directory by default
  declare -a directoriesToCheck=(
                "."
                 )

  #if it's plugins directory, enter each subdirectory and update the pom file
  if [[ $CURRENT_DIR =~ .*Plugins$ ]]; then 
      directoriesToCheck=(*/)
  fi

  COMMIT_POM=false

  # if it's Plugins directory, it walks through all subdirectories and update the parent mvn
  # if it's not Plugins directory, it just go to current directory(.)  
  for subdir in "${directoriesToCheck[@]}"; 
  do 
      cd  $CURRENT_DIR/$subdir
      #run maven comments if pom.xml exists 
      if [[ -f "pom.xml" ]]; then
         
        if [[ ! "$2" = "branch" && ! "$3" = "branch" ]]  # if it's not branch, update the version
        then 
          if [ "$2" = "self" ]
          then
              #project's own version is updated
              mvn versions:set -DnewVersion=$NEW_VERSION
          else
              #project's parent is updated
              mvn versions:update-parent -DparentVersion=$NEW_VERSION $ALLOW_SNAPSHOT
          fi
          check $?

          #add change pom.xml
          git add pom.xml
          check $?
          
          COMMIT_POM=true
        fi
      fi
  done

  if [ "$COMMIT_POM" = true ] ; then
    #commit pom.xml
    git commit -m "Update version to $NEW_VERSION"
    check $?
  fi

  #push branch to remote
  if [[ ! $NEW_VERSION =~ .*SNAPSHOT$ ]];
  then
     # if it is not snapshot push to the origin with branch name
     git push -u origin $BRANCH_NAME
  else
    # if it is snapshot, just push HEAD to the origin
    git push origin HEAD
  fi
  check $?

  if [[ ! "$2" = "branch" && ! "$3" = "branch" ]]  # if it's not branch, tag the version
  then 
    if [[ ! $NEW_VERSION =~ .*SNAPSHOT$ ]];
    then
      #tag branch
      git tag $TAG_NAME
      check $?
      #push tags
      git push origin --tags
      check $?
    fi
  fi
}

CURRENT_PATH=`pwd`
declare -a arr=(
                 "Ant-Media-Server"
                 "Ant-Media-Enterprise"
                 "ManagementConsole_AngularApp"
                 "StreamApp"
                 "webrtc-test"
                 "testcluster"
                 "Plugins"
                 )

VERSION=$1
BRANCH_PARAMETER=$2

PARENT_PATH=$CURRENT_PATH/Ant-Media-Server-Parent
cd $PARENT_PATH

update_version_and_push $VERSION self $BRANCH_PARAMETER
mvn install -Dgpg.skip=true

##  loop through the  array
for i in "${arr[@]}"
do
   echo "Entering $i"
   cd $CURRENT_PATH/$i
   update_version_and_push $VERSION $BRANCH_PARAMETER
done

if [[  $VERSION =~ .*SNAPSHOT$ ]];
then
  echo "Make Pull Request to master branch for all projects below"
else
  echo "Check that all projects below have passed CI/CD"
fi

echo "Ant-Media-Server-Parent"
for i in "${arr[@]}"
do
   echo "$i"
done
