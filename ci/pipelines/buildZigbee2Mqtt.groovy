pipeline {
    agent {
        label 'devenv'
    }
    parameters {
        string(name: 'REPO', defaultValue: 'https://github.com/koenkk/zigbee2mqtt', description: 'repo to get zigbee2mqtt from')
        string(name: 'BRANCH', defaultValue: 'master', description: 'for checkout step')
        string(name: 'TAG', defaultValue: '', description: 'use with VERSION_TO_NAME to build custom version')
        booleanParam(name: 'VERSION_TO_NAME', defaultValue: false, description: 'build package like zigbee2mqtt-1.18.1')
        booleanParam(name: 'UPLOAD_TO_POOL', defaultValue: false, description: 'disabled by default for repo safety')
        booleanParam(name: 'FORCE_OVERWRITE', defaultValue: false,
                description: 'use only you know what you are doing, replace existing version of package')
        string(name: 'WBDEV_IMAGE', defaultValue: 'contactless/devenv:latest',
                description: 'docker image to use as devenv')
        string(name: 'NPM_REGISTRY', defaultValue: 'http://r.cnpmjs.org/',
                description: 'select alternative mirror if necessary, e.g. https://registry.npmjs.org/')
    }
    environment {
        PROJECT_SUBDIR = 'zigbee2mqtt'
        RESULT_SUBDIR = 'result'
    }
    stages {
        stage('Cleanup workspace') { steps {
            cleanWs deleteDirs: true, patterns: [[pattern: "$RESULT_SUBDIR", type: 'INCLUDE']]
        }}
        stage('Checkout') { steps { dir("$PROJECT_SUBDIR") {
            git branch: params.BRANCH, url: params.REPO
        }}}
        stage('Checkout tag') {
            when { expression {
                (params.TAG != "")
            }}
            steps { dir("$PROJECT_SUBDIR") {
                sshagent (credentials: ['jenkins-github-public-ssh']) {
                    sh 'git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && git fetch --all'
                    sh "git checkout ${params.TAG}"
                }
            }}
        }
        stage('Determine version') {
            steps { dir("$PROJECT_SUBDIR") { script {
                sshagent (credentials: ['jenkins-github-public-ssh']) {
                    sh 'git config --add remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*" && git fetch --all'
                }
                env.VERSION = sh(returnStdout: true, script: "git describe --tags | sed -e 's/-.*//g'").trim()
                echo "Version: $VERSION"
            }}}
        }

        stage('Build') {
            environment {
                WBDEV_BUILD_METHOD="qemuchroot"
                WBDEV_TARGET="stretch-armhf"
            }
            steps { script {
                writeFile(file: "zigbee2mqtt.service", text: """[Unit]
Description=zigbee2mqtt
After=network.target

[Service]
ExecStart=/usr/bin/npm start
WorkingDirectory=/mnt/data/root/zigbee2mqtt
StandardOutput=inherit
StandardError=inherit
Restart=always
RestartSec=90
StartLimitInterval=400
StartLimitBurst=3
User=root

[Install]
WantedBy=multi-user.target
""")
                writeFile(file: "after-upgrade.sh", text: """
CONFIG_FILE=/mnt/data/root/zigbee2mqtt/data/configuration.yaml

if [ -e "\$CONFIG_FILE.wb-old" ]; then
    echo "Restoring config file after upgrade from old malformed zigbee2mqtt package version"
    mv \$CONFIG_FILE.wb-old \$CONFIG_FILE
fi
""")
                writeFile(file: "before-upgrade.sh", text: """
# In older zigbee2mqtt package builds data/configuration.yaml file
# is not marked as conffile so it is not preserved during upgrade.
# This script saves old configuration during upgrade from this
# malformed version.

CONFIG_FILE=/mnt/data/root/zigbee2mqtt/data/configuration.yaml

if ! dpkg-query --showformat='\${Conffiles}' --show zigbee2mqtt | grep configuration.yaml >/dev/null; then
    echo "Saving modified config file from old malformed zigbee2mqtt package"
    mv \$CONFIG_FILE \$CONFIG_FILE.wb-old
fi
""")

                writeFile(file: "$PROJECT_SUBDIR/data/configuration.yaml", text: """homeassistant: false
permit_join: false
mqtt:
  base_topic: zigbee2mqtt
  server: 'mqtt://localhost'
serial:
  port: /dev/ttyMOD3
advanced:
  rtscts: false
  last_seen: epoch
""")
                def name = params.VERSION_TO_NAME ? "zigbee2mqtt-${VERSION}" : "zigbee2mqtt";
                def specialParams = "";
                if (params.VERSION_TO_NAME) {
                    specialParams = "--provides zigbee2mqtt --conflicts zigbee2mqtt --replaces zigbee2mqtt"
                }

                sh "printenv | sort"
                sh "wbdev root printenv | sort"
                sh """wbdev chroot bash -xe -c "curl -sL https://deb.nodesource.com/setup_12.x | bash -;
                        apt-get install -y nodejs git make g++ gcc ruby ruby-dev rubygems build-essential;
                        gem install --no-document fpm -v 1.11.0;
                        npm set registry ${params.NPM_REGISTRY};
                        pushd $PROJECT_SUBDIR; npm ci; popd;
                        mkdir -p $RESULT_SUBDIR;
                        fpm -s dir -t deb -n ${name} \\
                            --exclude 'mnt/data/root/zigbee2mqtt/.git*' \\
                            --config-files mnt/data/root/zigbee2mqtt/data/configuration.yaml \\
                            --deb-no-default-config-files \\
                            --deb-systemd zigbee2mqtt.service \\
                            --deb-recommends wb-zigbee2mqtt \\
                            -m 'Wiren Board Robot <info@wirenboard.com>' \\
                            --description 'Zigbee to MQTT bridge (package by Wiren Board team)' \\
                            --url '${params.REPO}' \\
                            --vendor 'Wiren Board' \\
                            -d 'nodejs (>= 12.18.4)' \\
                            --before-upgrade before-upgrade.sh \\
                            --after-upgrade after-upgrade.sh \\
                            -p $RESULT_SUBDIR/${name}_${VERSION}_armhf.deb \\
                            -v ${VERSION} \\
                            ${specialParams} \\
                            $PROJECT_SUBDIR=/mnt/data/root ;"
                """
            }}
            post {
                always {
                    sh 'wbdev root chown -R jenkins:jenkins .'
                }
                success {
                    archiveArtifacts artifacts: "$RESULT_SUBDIR/*.deb"
                }
            }
        }

        stage('Setup deploy') {
            when { expression {
                params.UPLOAD_TO_POOL
            }}
            steps { script {
                wbDeploy projectSubdir: env.PROJECT_SUBDIR,
                        forceOverwrite: params.FORCE_OVERWRITE,
                        filesFilter: "$RESULT_SUBDIR/*.deb",
                        withGithubRelease: false
            }}
        }
    }
}
