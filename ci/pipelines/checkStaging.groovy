pipeline {
    agent {
        label "devenv"
    }
    parameters {
        string(name: 'BOARDS', defaultValue: '67 6x', description: 'boards to build images for')
        string(name: 'WIRENBOARD_BRANCH', defaultValue: 'feature/32254-releases', description: 'wirenboard/wirenboard repo branch')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest', description: 'tag for wbdev')
        booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false, description: 'use only if you know what you are doing')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "$WIRENBOARD_BRANCH", url: 'git@github.com:wirenboard/wirenboard'
            }
        }
        stage('Build testing images') {
            steps {
                script {
                    def targets = params.BOARDS.split(' ')
                    def jobs = [:]

                    for (target in targets) {
                        def currentTarget = target
                        jobs["build ${currentTarget}"] = {
                            stage("Build image for ${currentTarget}") {
                                build job: 'pipelines/build-image', wait: true, parameters: [
                                    string(name: 'BOARD', value: currentTarget),
                                    string(name: 'WB_TARGET', value: 'all'),
                                    string(name: 'WB_RELEASE', value: 'staging')
                                ]
                            }
                        }
                    }

                    parallel jobs
                }
            }
        }
        stage('Advance testing') {
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
            steps {
                build job: 'contactless/wb-releases/master', wait: true, parameters: [
                    booleanParam(name: 'FORCE_OVERWRITE', value: params.FORCE_OVERWRITE)
                ]
            }
        }
    }
}
