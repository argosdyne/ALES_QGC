pipeline {
    agent { label 'linux' }

    options {
        timestamps()
        ansiColor('xterm')
    }

    environment {
        QT_VERSION = '5.15.2'
        // BUILD_TYPE is computed in Init: StableBuild for tags/Stable branches, else DailyBuild
    }

    stages {
        stage('Init') {
            steps {
                script {
                    // Derive build type similar to GitHub Actions logic
                    def ref = env.GIT_BRANCH ?: ''
                    def isTag = ref.startsWith('refs/tags/v')
                    def isStable = ref.contains('Stable_') || ref.contains('Stable')
                    env.BUILD_TYPE = (isTag || isStable) ? 'StableBuild' : 'DailyBuild'
                    echo "Build type: ${env.BUILD_TYPE} (ref: ${ref})"
                }
            }
        }

        stage('Prepare tools') {
            steps {
                sh '''
                  sudo apt-get update
                  sudo apt-get install -y build-essential ninja-build ccache python3-pip wget unzip
                  python3 -m pip install --upgrade pip
                  python3 -m pip install --upgrade aqtinstall
                '''
            }
        }

        stage('Install Qt (Android)') {
            steps {
                sh '''
                  mkdir -p $HOME/Qt
                  aqt install-qt linux android ${QT_VERSION} android --outputdir $HOME/Qt --modules qtcharts
                '''
            }
        }

        stage('Install Android NDK r21e') {
            environment {
                NDK_VERSION = 'r21e'
            }
            steps {
                sh '''
                  mkdir -p $HOME/Android
                  cd $HOME/Android
                  if [ ! -d "android-ndk-${NDK_VERSION}" ]; then
                    wget -q https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux-x86_64.zip
                    unzip -q android-ndk-${NDK_VERSION}-linux-x86_64.zip
                  fi
                '''
            }
        }

        stage('Fetch gstreamer (Android)') {
            steps {
                sh '''
                  cd $WORKSPACE
                  wget --quiet https://gstreamer.freedesktop.org/data/pkg/android/1.18.6/gstreamer-1.0-android-universal-1.18.6.tar.xz
                  mkdir -p gstreamer-1.0-android-universal-1.18.6
                  tar xf gstreamer-1.0-android-universal-1.18.6.tar.xz -C gstreamer-1.0-android-universal-1.18.6
                '''
            }
        }

        stage('Build (32/64-bit in parallel)') {
            environment {
                QT_ANDROID_HOME = '$HOME/Qt/5.15.2/android'
                ANDROID_NDK_HOME = '$HOME/Android/android-ndk-r21e'
            }
            steps {
                script {
                    def builds = [
                        'armeabi-v7a': [artifact: 'QGroundControl32.apk'],
                        'arm64-v8a' : [artifact: 'QGroundControl64.apk']
                    ]

                    parallel builds.collectEntries { abi, cfg ->
                        ["${abi}": {
                            stage("Build ${abi}") {
                                sh """
                                  export PATH=${QT_ANDROID_HOME}/bin:${ANDROID_NDK_HOME}:${PATH}
                                  mkdir -p ${WORKSPACE}/shadow_build/${abi}
                                  cd ${WORKSPACE}/shadow_build/${abi}
                                  qmake -r ${WORKSPACE}/qgroundcontrol.pro -spec android-clang CONFIG+=${BUILD_TYPE} CONFIG+=installer ANDROID_ABIS="${abi}"
                                  make -j2
                                """

                                // Archive output APK (expected at shadow_build/${abi}/package/<artifact>)
                                archiveArtifacts artifacts: "shadow_build/${abi}/package/${cfg.artifact}", fingerprint: true
                            }
                        }]
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'ccache -s || true'
        }
    }
}
