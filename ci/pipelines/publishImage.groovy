// This pipeline takes firmware images from scecified pipelines/build-image build
// and publishes them on Amazon S3 cloud to make them available for users.
//
// Used in Jenkins job pipelines/publish-image.
//
// This job is triggered by pipelines/release-images.

pipeline {
    agent {
        label "devenv"
    }
    parameters {
        string(name: 'IMAGE_BUILDNUMBER', defaultValue: '', description: 'from pipelines/build-image')
        booleanParam(name: 'SET_LATEST', defaultValue: false, description: 'remove saved rootfs images before build')
        booleanParam(name: 'PUBLISH_IMG', defaultValue: true, description: 'works with SET_LATEST=true')
        string(name: 'LATEST_NAME', defaultValue: 'latest', description: 'used to publish "latest_*.fit, .md5 and .img files')
    }
    environment {
        S3CMD_CONFIG = credentials('s3cmd-fw-releases-config')
        TARGET_DIR = "image-${params.IMAGE_BUILDNUMBER}"
        S3_ROOTDIR = "s3://fw-releases.wirenboard.com/fit_image"
    }
    stages {
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
                        def parserRegex = '[0-9]*_(.*)_(.*)_wb(.*)\\.fit'
                        def sectionRegex = '\\1'
                        def debianVersionRegex = '\\2'
                        def boardRegex = '\\3'

                        def fitName = sh(returnStdout: true, script: 'ls *.fit').trim()
                        def releaseName = sh(returnStdout: true, script: """
                            echo ${fitName} | sed -E 's#${parserRegex}#${sectionRegex}#'""").trim()
                        def boardVersion = sh(returnStdout: true, script: """
                            echo ${fitName} | sed -E 's#${parserRegex}#${boardRegex}#'""").trim()

                        if (releaseName == fitName) {
                            error('FIT filename parsing failed')
                        }

                        // if release name is wb-XXXX, make image stable
                        def remoteSection = releaseName;
                        if (remoteSection ==~ /^wb\-\d+/) {
                            remoteSection = 'stable';
                        }

                        if (params.PUBLISH_IMG) {
                            sh 'unzip *.img.zip'
                            env.IMG_NAME = sh(returnStdout: true, script: 'ls *.img').trim()
                            env.IMG_ZIP_NAME = sh(returnStdout: true, script: 'ls *.img.zip').trim()
                        }

                        env.FIT_NAME = fitName
                        env.S3_PREFIX = "${env.S3_ROOTDIR}/${remoteSection}/${boardVersion}"
                    }
                }
            }
        }
        stage('Publish image') {
            steps {
                dir(env.TARGET_DIR) {
                    sh '''s3cmd -c $S3CMD_CONFIG put $FIT_NAME ${S3_PREFIX}/${FIT_NAME} \
                        --add-header="Content-Disposition: attachment; filename=\\"$FIT_NAME\\""'''
                }
            }
        }
        stage('Publish latest FIT') {
            when { expression {
                params.SET_LATEST
            }}
            environment {
                FIT_MD5_NAME = "${params.LATEST_NAME}.fit.md5"
                FIT_PUB_NAME = "${params.LATEST_NAME}.fit"
            }
            steps {
                dir(env.TARGET_DIR) {
                    sh 'md5sum $FIT_NAME | awk \'{print \$1}\' > $FIT_MD5_NAME'
                    sh 's3cmd -c $S3CMD_CONFIG put $FIT_MD5_NAME ${S3_PREFIX}/${FIT_MD5_NAME}'
                    sh '''s3cmd -c $S3CMD_CONFIG put $FIT_NAME ${S3_PREFIX}/${FIT_PUB_NAME} \
                        --add-header="Content-Disposition: attachment; filename=\\"$FIT_NAME\\""'''
                }
            }
        }

        stage('Publish latest IMG') {
            when { expression {
                params.PUBLISH_IMG && params.SET_LATEST
            }}
            environment {
                IMG_PUB_NAME = "${params.LATEST_NAME}.img"
            }
            steps {
                dir(env.TARGET_DIR) {
                    sh 'md5sum $IMG_NAME | awk \'{print \$1}\' > ${IMG_PUB_NAME}.md5'
                    sh 'md5sum $IMG_ZIP_NAME | awk \'{print \$1}\' > ${IMG_PUB_NAME}.zip.md5'
                    sh 's3cmd -c $S3CMD_CONFIG put ${IMG_PUB_NAME}.md5 ${S3_PREFIX}/${IMG_PUB_NAME}.md5'
                    sh 's3cmd -c $S3CMD_CONFIG put ${IMG_PUB_NAME}.zip.md5 ${S3_PREFIX}/${IMG_PUB_NAME}.zip.md5'
                    sh 's3cmd -c $S3CMD_CONFIG put $IMG_NAME ${S3_PREFIX}/${IMG_PUB_NAME}'
                    sh 's3cmd -c $S3CMD_CONFIG put $IMG_ZIP_NAME ${S3_PREFIX}/${IMG_PUB_NAME}.zip'
                }
            }
        }
    }
}
