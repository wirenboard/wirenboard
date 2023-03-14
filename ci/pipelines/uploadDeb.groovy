Map uploadJobs = [
  release: 'wirenboard/wb-releases/master',
  devtools: 'wirenboard/wb-dev-tools-releases/master'
]

pipeline {
  agent any
  parameters {
    stashedFile 'upload.deb'
    choice(name: 'REPO', choices: ['release', 'devtools'], description: 'which repo to publish to')
    booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false,
                 description: 'use only you know what you are doing, replace existing version of package')
  }
  stages {
    stage('Setup deploy') {
      steps {
        script {
          unstash 'upload.deb'
          def deployArgs = [
            forceOverwrite: params.FORCE_OVERWRITE,
            uploadJob: uploadJobs[params.REPO],
            aptlyConfig: params.REPO + "-aptly-config",
            filesFilter: "*.deb",
            withGithubRelease: false
          ]

          wbDeploy(deployArgs)
        }
      }
    }
  }
}
