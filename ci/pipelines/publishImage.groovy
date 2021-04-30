pipeline {
    agent {
        label "devenv"
    }
    parameters {
        string(name: 'IMAGE_BUILDNUMBER', defaultValue: '', description: 'from pipelines/build-image')
        booleanParam(name: 'SET_LATEST', defaultValue: false, description: 'remove saved rootfs images before build')
        booleanParam(name: 'PUBLISH_IMG', defaultValue: false, description: 'works with SET_LATEST=true')
    }
    environment {
        S3CMD_CONFIG = credentials('s3cmd-fw-releases-config')
        TARGET_DIR = "image-${params.IMAGE_BUILDNUMBER}"
        S3_ROOTDIR = "s3://fw-releases.wirenboard.com/fit_image"
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "$WIRENBOARD_BRANCH", url: 'git@github.com:wirenboard/wirenboard'
            }
        }
        stage('Gather FIT image from build-image') {
            steps {
                copyArtifacts projectName: 'pipelines/build-image',
                              selector: specific(params.IMAGE_BUILDNUMBER),
                              filter: 'jenkins_output/*',
                              target: env.TARGET_DIR,
                              flatten: true,
                              fingerprintArtifacts: true
            }
        }
        stage('Determine names and statuses') {
            steps {
                dir(env.TARGET_DIR) {
                    script {
                        // FIXME: remove this weird magic with renaming, have no idea why is it here
                        def parserRegex = '([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})_(.*)_webupd_wb(.*)\\.fit'
                        def sectionRegex = '\\6'
                        def filenameRegex = 'wb-\\7-\\6-\\1-\\2-\\3_\\4:\\5:00.fit'

                        def fitName = sh(returnStdout: true, script: 'ls *.fit').trim()
                        def remoteSection = sh(returnStdout: true, script: """
                            echo ${fitName} | sed -E 's#${parserRegex}#${sectionRegex}#'""").trim()
                        def remoteName = sh(returnStdout: true, script: """
                            echo ${fitName} | sed -E 's#${parserRegex}#${filenameRegex}#'""").trim()

                        if (remoteName == fileName) {
                            error('FIT filename parsing failed')
                        }

                        if (params.PUBLISH_IMG) {
                            sh 'unzip *.img.zip'
                            def imgName = sh(returnStdout: true, script: 'ls *.img').trim()
                            env.IMG_NAME = imgName
                        }

                        env.FIT_NAME = fitName
                        env.REMOTE_SECTION = remoteSection
                        env.REMOTE_FIT_NAME = remoteName

                        env.S3_PREFIX = "${env.S3_ROOTDIR}/${env.REMOTE_SECTION}"
                    }
                }
            }
        }
        stage('Publish image') {
            steps {
                dir(env.TARGET_DIR) {
                    sh '''s3cmd -c $S3CMD_CONFIG put $FIT_NAME ${S3_PREFIX}/${REMOTE_FIT_NAME} \
                        --add-header="Content-Disposition: attachment; filename=\\"$FIT_NAME\\""'''
                }
            }
        }
        stage('Publish latest FIT') {
            when { expression {
                params.SET_LATEST
            }}
            environment {
                FIT_MD5_NAME = 'latest_stretch.fit.md5'
                FIT_PUB_NAME = 'latest_stretch.fit'
                FIT_FRESET_PUB_NAME = 'latest_stretch_FACTORYRESET.fit'
            }
            steps {
                dir(env.TARGET_DIR) {
                    sh 'md5sum $FIT_NAME | awk \'{print \$1}\' > $FIT_MD5_NAME'
                    sh 's3cmd -c $S3CMD_CONFIG put $FIT_MD5_NAME ${S3_PREFIX}/${FIT_MD5_NAME}'
                    sh '''s3cmd -c $S3CMD_CONFIG put $FIT_NAME ${S3_PREFIX}/${FIT_PUB_NAME} \
                        --add-header="Content-Disposition: attachment; filename=\\"$FIT_NAME\\""'''
                    sh '''s3cmd -c $S3CMD_CONFIG put $FIT_NAME ${S3_PREFIX}/${FIT_FRESET_PUB_NAME} \
                        --add-header="Content-Disposition: attachment; filename=\\"$FIT_NAME\\""'''
                }
            }
        }
        // FIXME: this step is weird, better to use FITs in the future
        stage('Publish latest IMG') {
            when { expression {
                params.PUBLISH_IMG && params.SET_LATEST
            }}
            environment {
                IMG_MD5_NAME = 'latest_stretch.img.md5'
                IMG_PUB_NAME = 'latest_stretch.img'
            }
            steps {
                dir(env.TARGET_DIR) {
                    sh 'md5sum $IMG_NAME | awk \'{print \$1}\' > $IMG_MD5_NAME'
                    sh 's3cmd -c $S3CMD_CONFIG put $IMG_MD5_NAME ${S3_PREFIX}/${IMG_MD5_NAME}'
                    sh 's3cmd -c $S3CMD_CONFIG put $IMG_NAME ${S3_PREFIX}/${IMG_PUB_NAME}'
                }
            }
        }
    }
}
