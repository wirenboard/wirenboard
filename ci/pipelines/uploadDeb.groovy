Map uploadJobs = [
  release: 'wirenboard/wb-releases/master',
  devtools: 'wirenboard/wb-dev-tools-releases/master'
]

pipeline {
  agent {
    label 'devenv'
  }
  parameters {
    stashedFile 'upload.deb'
    choice(name: 'REPO', choices: ['release', 'devtools'], description: 'which repo to publish to')
    booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false,
                 description: 'use only you know what you are doing, replace existing version of package')
  }
  environment {
    FILES_DIR = "files"
  }
  stages {
    stage('Cleanup workspace') {
      steps {
        cleanWs deleteDirs: true, patterns: [[pattern: "$FILES_DIR", type: 'INCLUDE']]
      }
    }
    stage('Prepare file') {
      steps { dir("$FILES_DIR") {
        unstash 'upload.deb'
        sh 'wbdev user dpkg-name upload.deb'
        archiveArtifacts artifacts: '*.deb'
      }}
    }
    stage('Setup deploy') {
      steps { script {
        def deployArgs = [
          forceOverwrite: params.FORCE_OVERWRITE,
          uploadJob: uploadJobs[params.REPO],
          aptlyConfig: params.REPO + "-aptly-config",
          withGithubRelease: false
        ]

        wbDeploy(deployArgs)
      }}
    }
  }
}
