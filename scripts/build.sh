#!/bin/bash


BASEDIR=$(pwd)
LOG=$BASEDIR/log_$( date +%Y%m%d%H%M%S ).txt
exec >$LOG 2>&1

BRANCH=R4_2_maintenance
GIT_PREFIX=ssh://git.eclipse.org
javaHome=/opt/local/jdk1.7.0_07
mvnPath=/opt/pwebster/git/cbi/apache-maven-3.0.4/bin
updateAggregator=false

while [ $# -gt 0 ]
do
    case "$1" in
	"-v")
	    mavenVerbose=-X;;
	"-bree-libs")
	    mavenBREE=-Pbree-libs;;
	"-sign")
	    mavenSign=-Peclipse-sign;;
	"-update")
	    updateAggregator=true;;
	"-anonymous")
	    GIT_PREFIX=git://git.eclipse.org;;
	"-gitPrefix")
	    GIT_PREFIX="$2" ; shift;;
	"-branch")
	    BRANCH="$2" ; shift;;
	"-javaHome")
	    javaHome="$2" ; shift;;
	"-mavenPath")
	    mvnPath="$2" ; shift;;
    esac
    shift
done


export MAVEN_OPTS=-Xmx2048m
LOCAL_REPO=$BASEDIR/localRepo


if [ -z "$JAVA_HOME" ]; then
    export JAVA_HOME=$javaHome
fi

mvnRegex=$( echo $mvnPath | sed 's!/!.!g' )
if ! (echo $PATH | grep "$mvnRegex" >/dev/null ); then
    export PATH=${mvnPath}:$PATH
fi


cloneAggregator() {
    if [ ! -d eclipse.platform.releng.aggregator ]; then
	git clone \
	-b $BRANCH \
	${GIT_PREFIX}/gitroot/platform/eclipse.platform.releng.aggregator.git
	pushd eclipse.platform.releng.aggregator
	git submodule init
	# this will take a while ... a long while
	git submodule update
	popd
    else
	pushd eclipse.platform.releng.aggregator
	git fetch
	git checkout $BRANCH
	git pull
	git submodule update
	popd
    fi
}

installEclipseParent () {
    pushd eclipse.platform.releng.aggregator
    mvn -f eclipse-parent/pom.xml \
    clean install \
    -Dmaven.repo.local=$LOCAL_REPO
    popd
}

installMavenCbi () {
    pushd eclipse.platform.releng.aggregator
    mvn -f maven-cbi-plugin/pom.xml \
    clean install \
    -Dmaven.repo.local=$LOCAL_REPO
    popd
}

installEclipseSigner () {
    if [ ! -d org.eclipse.cbi.maven.plugins ]; then
	git clone -n \
	${GIT_PREFIX}/gitroot/cbi/org.eclipse.cbi.maven.plugins.git
    fi
    pushd org.eclipse.cbi.maven.plugins
    git fetch
    git checkout eclipse-jarsigner-plugin-1.0.1
    mvn -f eclipse-jarsigner-plugin/pom.xml \
    clean install \
    -Dmaven.repo.local=$LOCAL_REPO
    popd
}

buildAggregator () {
    pushd eclipse.platform.releng.aggregator
    mvn $mavenVerbose \
    clean install \
    $mavenSign \
    $mavenBREE \
    -Dmaven.test.skip=true \
    -Dmaven.repo.local=$LOCAL_REPO
    popd
}

# steps to get going

if $updateAggregator; then
    cloneAggregator
fi

# if you want to sign on build.eclipse.org. you need this
if [ ! -z "$mavenSign" ]; then
    installEclipseSigner
fi

# pick up any changes
installEclipseParent
installMavenCbi

# build from the aggregator root
buildAggregator

