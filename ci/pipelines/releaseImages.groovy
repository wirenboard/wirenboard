// This pipeline triggers pipelines/build-image job to build stable images
// and then triggers pipelines/publish-image job to publish these images.
//
// Used in Jenkins job pipelines/release-images.
//
// wirenboard/wb-releases schedules this job if releases.yaml is changed, so
// new images are published automatically when our packages are updated.

def imagesJobs = []

pipeline {
    agent {
        label "devenv"
    }
    parameters {
        string(name: 'DEB_RELEASE', defaultValue: 'stretch', description: 'Debian release')
        string(name: 'BOARDS', defaultValue: '6x 67 7x', description: 'space-separated list')
        string(name: 'WIRENBOARD_BRANCH', defaultValue: 'master', description: 'wirenboard/wirenboard repo branch')
        string(name: 'WB_RELEASE', defaultValue: 'stable', description: 'wirenboard release (from WB repo)')
        booleanParam(name: 'CLEANUP_ROOTFS', defaultValue: false, description: 'remove saved rootfs images before build')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest', description: 'tag for wbdev')
    }
    stages {
        stage('Build images') {
            steps {
                script {
                    def boards = params.BOARDS.split(' ')

                    for (board in boards) {
                        def currentBoard = board
                        def imageJob = build(
                            job: 'pipelines/build-image',
                            wait: true,
                            parameters: [
                                string(name: 'DEB_RELEASE', value: params.DEB_RELEASE),
                                string(name: 'BOARD', value: currentBoard),
                                string(name: 'WIRENBOARD_BRANCH', value: params.WIRENBOARD_BRANCH),
                                string(name: 'WB_RELEASE', value: params.WB_RELEASE),
                                string(name: 'WBDEV_IMAGE', value: params.WBDEV_IMAGE),
                                booleanParam(name: 'CLEANUP_ROOTFS', value: params.CLEANUP_ROOTFS),
                                booleanParam(name: 'SAVE_ARTIFACTS', value: true)
                            ])

                        imagesJobs.add(imageJob)
                    }
                }
            }
        }
        stage('Publish images') {
            steps {
                script {
                    def jobs = [:]

                    for (job in imagesJobs) {
                        def currentImageJob = job
                        jobs["publish ${currentImageJob.getId()}"] = {
                            stage("Publish ${currentImageJob.getId()}") {
                                build(job: 'pipelines/publish-image',
                                      wait: true,
                                      parameters: [
                                        string(name: 'IMAGE_BUILDNUMBER', value: currentImageJob.getId()),
                                        booleanParam(name: 'SET_LATEST', value: true),
                                        booleanParam(name: 'PUBLISH_IMG', value: false)
                                      ])
                            }
                        }
                    }

                    parallel jobs
                }
            }
        }
    }
}
