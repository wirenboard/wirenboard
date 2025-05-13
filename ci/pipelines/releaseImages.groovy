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
        label "rootfs-builder"
    }
    parameters {
        string(name: 'DEBIAN_RELEASE', defaultValue: 'bullseye', description: 'Debian release')
        string(name: 'BOARDS', defaultValue: '6x 67 7x 8x', description: 'space-separated list')
        string(name: 'ADDITIONAL_REPOS', defaultValue: '', description: 'space-separated for multiple repos')
        string(name: 'WIRENBOARD_BRANCH', defaultValue: 'master', description: 'wirenboard/wirenboard repo branch')
        string(name: 'WB_RELEASE', defaultValue: 'stable', description: 'wirenboard release (from WB repo)')
        booleanParam(name: 'CLEANUP_ROOTFS', defaultValue: false, description: 'remove saved rootfs images before build')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest', description: 'tag for wbdev')
        string(name: 'TEST_JOB', defaultValue: 'wirenboard/wb-release-tests/main')
        booleanParam(name: 'ENABLE_TELEGRAM_ALERT', defaultValue: true, description: 'send alert to WB Monitoring if build is failed/restored')
        booleanParam(name: 'TEST_FACTORYRESET', defaultValue: true, description: 'run factory reset tests on images (wb7 only)')
        booleanParam(name: 'TEST_STANDALONE', defaultValue: true, description: 'run generic FIT update tests on images')
        booleanParam(name: 'PUBLISH_IMAGES', defaultValue: true, description: 'publish images')
    }
    triggers {
        parameterizedCron('''
            @weekly %DEBIAN_RELEASE=bullseye;WB_RELEASE=testing
        ''')
    }
    stages {
        stage('Build images') {
            steps {
                script {
                    def boards = params.BOARDS.split(' ')
                    def jobs = [:]

                    for (board in boards) {
                        def currentBoard = board
                        jobs["build ${currentBoard}"] = {
                            stage("Build image for ${currentBoard}") { script {
                                def imageJob = build(
                                    job: 'pipelines/build-image',
                                    wait: true,
                                    parameters: [
                                        string(name: 'DEBIAN_RELEASE', value: params.DEBIAN_RELEASE),
                                        string(name: 'BOARD', value: currentBoard),
                                        string(name: 'ADDITIONAL_REPOS', value: params.ADDITIONAL_REPOS),
                                        string(name: 'WIRENBOARD_BRANCH', value: params.WIRENBOARD_BRANCH),
                                        string(name: 'WB_RELEASE', value: params.WB_RELEASE),
                                        string(name: 'WBDEV_IMAGE', value: params.WBDEV_IMAGE),
                                        booleanParam(name: 'CLEANUP_ROOTFS', value: params.CLEANUP_ROOTFS),
                                        booleanParam(name: 'SAVE_ARTIFACTS', value: true)
                                    ])
                                imagesJobs.add([ job: imageJob, board: currentBoard ])
                            }}
                        }
                    }

                    parallel jobs
                }
            }
        }
        stage('Test images') {
            when { expression { params.TEST_FACTORYRESET || params.TEST_STANDALONE } }
            steps {
                script {
                    def jobs = [:]

                    for (item in imagesJobs) {
                        def currentImageJob = item.job
                        def currentBoard = item.board

                        jobs["test ${currentImageJob.getId()}"] = {
                            stage("Test ${currentBoard} ${currentImageJob.getId()}") {
                                build(job: 'pipelines/release-test-orchestrator',
                                      wait: true,
                                      parameters: [
                                        string(name: 'BENCH_BOARD', value: currentBoard),
                                        string(name: 'FIT_BUILDID', value: currentImageJob.getId()),
                                        string(name: 'WIRENBOARD_BRANCH', value: params.WIRENBOARD_BRANCH),
                                        string(name: 'WBDEV_IMAGE', value: params.WBDEV_IMAGE),
                                        string(name: 'TEST_JOB', value: params.TEST_JOB),
                                        booleanParam(name: 'RUN_FACTORYRESET', value: params.TEST_FACTORYRESET && currentBoard == '7x'),
                                        booleanParam(name: 'RUN_STANDALONE', value: params.TEST_STANDALONE),
                                        booleanParam(name: 'RUN_RELEASE', value: false),  // suitable for release updates, not image publish
                                        booleanParam(name: 'RUN_LEGACY', value: false),  // suitable for 6x boards and not for image publish
                                      ])
                            }
                        }
                    }

                    parallel jobs
                }
            }
        }
        stage('Publish images') {
            when { expression { params.PUBLISH_IMAGES } }
            steps {
                script {
                    def jobs = [:]

                    for (item in imagesJobs) {
                        def currentImageJob = item.job
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
    post {
        always { script {
            if (params.ENABLE_TELEGRAM_ALERT) {
                wb.notifyMaybeBuildRestored("Boards: ${params.BOARDS}, WB release: ${params.WB_RELEASE}")
            }
        }}
        failure { script {
            if (params.ENABLE_TELEGRAM_ALERT) {
                wb.notifyBuildFailed("Boards: ${params.BOARDS}, WB release: ${params.WB_RELEASE}")
            }
        }}
    }
}
