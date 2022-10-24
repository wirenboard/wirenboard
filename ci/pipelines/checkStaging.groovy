// This pipeline checks current staging repository consistency by building firmware images
// for devices which can run staging. If checks are successful, unstable repository updates
// to current staging.
//
// Used in Jenkins job pipelines/check-staging.
//
// wirenboard/wb-releases triggers this job, so it runs when new packages are added to staging.
//
// Image building is pretty time-consuming. To avoid unnecessary builds, this pipeline checks
// if unstable and staging are not the same before proceed.

def changesDetected = false

pipeline {
    agent {
        label "devenv"
    }
    parameters {
        string(name: 'DEBIAN_RELEASE', defaultValue: 'bullseye', description: 'debian release')
        string(name: 'BOARDS', defaultValue: '67 7x', description: 'boards to build images for')
        string(name: 'WIRENBOARD_BRANCH', defaultValue: 'master', description: 'wirenboard/wirenboard repo branch')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest', description: 'tag for wbdev')
        booleanParam(name: 'ADVANCE_UNSTABLE', defaultValue: true, description: 'disable if you want just to check')
        booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false, description: 'use only if you know what you are doing')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "$WIRENBOARD_BRANCH", url: 'git@github.com:wirenboard/wirenboard'
            }
        }
        stage('Check difference') {
            environment {
                APTLY_CONFIG = credentials('release-aptly-config')
            }
            steps {
                lock('release-aptly-config-db') {
                    script {
                        def currentStaging = sh(returnStdout: true,
                          script: 'wbci-repo -c $APTLY_CONFIG deref staging.latest')
                        def currentUnstable = sh(returnStdout: true,
                          script: 'wbci-repo -c $APTLY_CONFIG deref unstable.latest')
                        changesDetected = (currentUnstable != currentStaging)
                    }
                }
            }
        }
        stage('Build staging images') {
            when { expression {
                changesDetected
            }}
            steps {
                script {
                    def targets = params.BOARDS.split(' ')

                    for (target in targets) {
                        def currentTarget = target
                        stage("Build image for ${currentTarget}") {
                            build job: 'pipelines/build-image', wait: true, parameters: [
                                string(name: 'DEBIAN_RELEASE', value: params.DEBIAN_RELEASE),
                                string(name: 'BOARD', value: currentTarget),
                                string(name: 'WB_TARGET', value: 'all'),
                                string(name: 'WB_RELEASE', value: 'staging'),
                                string(name: 'WIRENBOARD_BRANCH', value: params.WIRENBOARD_BRANCH),
                                booleanParam(name: 'SAVE_ARTIFACTS', value: false)
                            ]
                        }
                    }
                }
            }
        }
        stage('Advance unstable') {
            when { expression {
                changesDetected && params.ADVANCE_UNSTABLE
            }}
            environment {
                APTLY_CONFIG = credentials('release-aptly-config')
            }
            steps {
                lock('release-aptly-config-db') {
                    sh '''wbci-repo -c $APTLY_CONFIG make-ref -u -d "ci job:$JOB_NAME build:$BUILD_ID" \\
                          unstable.latest $(wbci-repo -c $APTLY_CONFIG deref staging.latest)'''
                }
            }
        }
        stage('Upload via wb-releases') {
            when { expression {
                changesDetected && params.ADVANCE_UNSTABLE
            }}
            steps {
                build job: 'wirenboard/wb-releases/master', wait: true, parameters: [
                    booleanParam(name: 'FORCE_OVERWRITE', value: params.FORCE_OVERWRITE)
                ]
            }
        }
    }
}
