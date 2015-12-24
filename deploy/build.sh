#!/bin/bash
## this script is used by jenkins or a developer with local build of MapLoom
## to update the django-maploom project after building latest maploom

# exit if anything returns failure
set -e

echo 'current directory:' pwd


if [ "$1" = "jenkins" ]; then
  JENKINS_MODE=true
elif [ "$1" = "dev" ]; then
  JENKINS_MODE=false
else
    echo "usage: "
    echo "       deploy jenkins"
    echo "           assumes maploom is found and already built at ../../maploom/lastSuccessful/archive"
    echo "       deploy dev"
    echo "           assumes maploom is found and already built at ../MapLoom"
    exit 1
fi

git checkout master

# path to the maploom build that will be used
if [ $JENKINS_MODE == true ]; then
  MAPLOOM_PATH=../../maploom/lastSuccessful/archive
  MAPLOOM_REPO=../../maploom/workspace
else
  MAPLOOM_PATH=../MapLoom
  MAPLOOM_REPO=$MAPLOOM_PATH
fi

echo "Using maploom build at: "$MAPLOOM_PATH

# get the new index.html file and use it to make the partial
sed -n '/body class="maploom-body">/,/body>/p' $MAPLOOM_PATH/bin/index.html > index_body.html
sed '/body>/d' ./index_body.html > index_body_no_tag.html
echo '{% load staticfiles i18n %}{% verbatim %}' > _maploom_map.html
cat index_body_no_tag.html >> _maploom_map.html
echo '{% endverbatim %}' >> _maploom_map.html
rm index_body.html
rm index_body_no_tag.html

# remove data we will overwrite shortly
rm -r maploom/static/maploom/assets
rm -r maploom/static/maploom/fonts
rm maploom/templates/maploom/_maploom_map.html

#copy the new fonts assets
cp -r $MAPLOOM_PATH/bin/assets maploom/static/maploom/
cp -r $MAPLOOM_PATH/bin/fonts maploom/static/maploom/
mv _maploom_map.html maploom/templates/maploom

# get the commit id of the last commit of the maploom repo and the current date-time to build 
# a version number which we can set in setup.py
VER_DATE=`date +%Y-%m-%d.%H:%M:%S`
pushd .
cd $MAPLOOM_REPO
VER_SHA1=`git log --format="%H" | head -n1 | cut -c 1-10`
popd
VER=$VER_DATE.$VER_SHA1
#echo "s|^    version=.*|    version='0.0.1@"$VER_DATE.$VER_SHA1"',|" ./setup.py
sed -ie "s|^    version=.*|    version='0.0.1@"$VER_DATE.$VER_SHA1"',|" ./setup.py

# if git status doesn't have 'nothing' (to commit) in it, go ahead and commit
# for this to work you can, 1) cd ~ 2) ssh-keygen -t rsa (Press enter for all values) 3) add pub key to the repo's deploy keys on github. 
if [[ $(git status) != *nothing* ]]; then
  git add .

  # path to the maploom build that will be used
  if [ $JENKINS_MODE == true ]; then
    COMMIT_MSG="jenkins job django-maploom: use latest maploom to build maploom django wrapper."
  else
    COMMIT_MSG="developer deployed using deploy script with dev flag."
  fi
  git commit -m "$COMMIT_MSG"
  git push origin master
fi

echo 'done!'