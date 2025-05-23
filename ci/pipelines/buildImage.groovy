// Builds firmware images for Wiren Board controllers.
//
// Used in Jenkins job pipelines/build-image.
//
// This job is triggered by pipelines/check-staging and pipelines/release-images.

pipeline {
    agent {
        label "rootfs-builder"
    }
    parameters {
        choice(name: 'BOARD', choices: wb.boards, description: 'Board version to build image for')
        choice(name: 'DEBIAN_RELEASE', choices: wb.debianReleases, description: 'Debian release')
        string(name: 'REPO_PREFIX', defaultValue: '', description: 'APT repository prefix (after deb.wirenboard.com)')
        string(name: 'ADDITIONAL_REPOS', defaultValue: '',
               description: 'space-separated for multiple repos, example: http://deb.wirenboard.com/all@experimental.foo:main')
        string(name: 'WIRENBOARD_BRANCH', defaultValue: 'master', description: 'wirenboard/wirenboard repo branch')
        string(name: 'WB_TARGET', defaultValue: '', description: 'leave empty for auto detection. Examples: wb6/stretch, all')
        string(name: 'WB_RELEASE', defaultValue: 'stable', description: 'wirenboard release (from WB repo)')
        booleanParam(name: 'CLEANUP_ROOTFS', defaultValue: false, description: 'remove saved rootfs images before build')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest', description: 'tag for wbdev')
        booleanParam(name: 'SAVE_ARTIFACTS', defaultValue: true, description: 'save image after build (may be disabled for staging checks)')
    }
    environment {
        OUT_DIR="jenkins_output/"
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "$WIRENBOARD_BRANCH",
                    url: 'git@github.com:wirenboard/wirenboard',
                    credentialsId: 'jenkins-github-public-ssh'
            }
        }
        stage('Cleanup old rootfs') {
            when { expression {
                params.CLEANUP_ROOTFS
            }}

            steps {
                sh 'wbdev root rm ./output/ -rf'
            }
        }
        stage('Build rootfs') {
            steps {
                script {
                    currentBuild.displayName = "#${BUILD_NUMBER} (${BOARD}/${WB_RELEASE})"
                }
                sh """
                    wbdev root bash -c 'rm -rf ./output/rootfs_wb$BOARD;
                    WB_REPO_PREFIX=$REPO_PREFIX WB_TARGET=$WB_TARGET WB_RELEASE=$WB_RELEASE \\
                    DEBIAN_RELEASE=$DEBIAN_RELEASE \\
                    bash -x ./rootfs/create_rootfs.sh $BOARD $ADDITIONAL_REPOS'
                """
            }
        }
        stage('Create image') {
            steps {
                cleanWs deleteDirs: true, patterns: [[pattern: "$OUT_DIR/", type: 'INCLUDE']]
                sh """
                    wbdev root bash -c 'mount -t devtmpfs none /dev;
                    OUT_DIR=$OUT_DIR MAKE_IMG=y ./image/create_images.sh $BOARD'
                """
            }
            post {
                always {
                    sh 'wbdev root chown -R jenkins:jenkins .'
                }
            }
        }
        stage('Archive image') {
            when { expression {
                params.SAVE_ARTIFACTS
            }}
            steps {
                archiveArtifacts artifacts: "$OUT_DIR/*.img.zip,$OUT_DIR/*.fit"
            }
        }
    }
}
