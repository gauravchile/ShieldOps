@Library('JenkinsSharedLibs') _

pipeline {
  agent any

  environment {
    USER            = 'gauravchile'
    REGISTRY        = 'docker.io'
    IMAGE_NAME      = 'shieldops'
    IMAGE_REPO      = "${REGISTRY}/${USER}/${IMAGE_NAME}"
    NAMESPACE       = 'shieldops'
    SCAN_DIR        = "${WORKSPACE}/reports"
    EMAIL_RECIPIENT = 'email.example@gmail.com'
    ODC_CACHE_DIR   = '/tmp/odc-data'
    PATH            = "/usr/local/bin:/usr/bin:/bin:/home/ubuntu/.local/bin:${PATH}"
  }

  options { timestamps() }

  stages {
    /* -------------------------------------------------------------------------- */
    stage('Checkout Code') {
      steps {
        echo "🔄 Cloning ShieldOps repository..."
        checkout scm
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Determine Semantic Version') {
      steps {
        script {
          def ver = getVersionTag(autoGitTag: true, gitCred: env.GIT_CRED ?: '')
          env.IMAGE_TAG = ver.tag
          echo "Resolved Version: ${env.IMAGE_TAG} (Mode: ${ver.mode})"
          currentBuild.displayName = "#${BUILD_NUMBER} - ${env.IMAGE_TAG}"
          currentBuild.description = "Version: ${env.IMAGE_TAG} | Security checks running"
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Prepare Environment') {
      steps {
        sh '''
          set -e
          mkdir -p "${SCAN_DIR}" "${ODC_CACHE_DIR}"
          if [ ! -d "${WORKSPACE}/.venv" ]; then
            python3 -m venv "${WORKSPACE}/.venv"
          fi
          . "${WORKSPACE}/.venv/bin/activate"
          python -m pip install --upgrade pip
          pip install --quiet bandit safety
        '''
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Verify Tools') {
      steps {
        sh '''
          echo "🔍 Verifying required tools..."
          for cmd in node npm docker helm kubectl trivy zap; do
            if command -v $cmd >/dev/null 2>&1; then
              echo "✅ $cmd version: $($cmd --version | head -n1)"
            else
              echo "❌ $cmd not found. Run ./shieldops-cluster-bootstrap.sh --tools"
              exit 1
            fi
          done
        '''
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Install Backend Dependencies') {
      steps {
        dir('backend') {
          sh '''
            rm -rf ~/.npm/_cacache || true
            npm install --omit=dev --no-audit --legacy-peer-deps
          '''
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Build UI (Vite)') {
      steps {
        dir('ui') {
          sh '''
            echo "VITE_API_BASE_URL=/api" > .env
            npm install --no-audit --legacy-peer-deps
            if ! npx vite --version >/dev/null 2>&1; then
              npm install vite --save-dev --no-audit --legacy-peer-deps
            fi
            npx vite build
          '''
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('SAST - ESLint, Bandit & CodeQL') {
      steps {
        script {
          dir('ui') {
            sh '''
              if [ ! -f ".eslintrc.json" ]; then
                echo "⚠️ No ESLint config found, skipping UI lint."
              else
                npx eslint@8 . -f json -o ../reports/eslint-report.json || true
              fi
            '''
          }

          dir('backend') {
            sh '''
              . "${WORKSPACE}/.venv/bin/activate"
              bandit -r . -f json -o ../reports/bandit-report.json || true
              if command -v codeql >/dev/null 2>&1; then
                codeql database create codeql-db --language=javascript --source-root=. --overwrite || true
                codeql database analyze codeql-db --format=sarif-latest --output=../reports/codeql-report.sarif || true
              fi
            '''
          }
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('SCA - Dependency Scans') {
      parallel {
        stage('Backend SCA') {
          steps {
            script {
              owasp_dependency_check(
                scanPath: 'backend',
                reportDir: env.SCAN_DIR,
                project: 'ShieldOps-backend',
                cacheDir: env.ODC_CACHE_DIR,
                additionalArgs: '--exclude **/node_modules/** --failOnCVSS 9'
              )
              dir('backend') {
                sh '''
                  . "${WORKSPACE}/.venv/bin/activate"
                  pip freeze > requirements.txt
                  safety check --file=requirements.txt --json > ../reports/safety-report.json || true
                  npx -y @cyclonedx/bom -o ../reports/bom-backend.json || true
                '''
              }
            }
          }
        }

        stage('UI SCA') {
          steps {
            script {
              owasp_dependency_check(
                scanPath: 'ui',
                reportDir: env.SCAN_DIR,
                project: 'ShieldOps-ui',
                cacheDir: env.ODC_CACHE_DIR
              )
              dir('ui') {
                sh 'npx -y @cyclonedx/bom -o ../reports/bom-frontend.json || true'
              }
            }
          }
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Build Docker Images') {
      steps {
        script {
          echo "🏗️ Building Docker images..."
          dir('backend') {
            docker_build("${env.IMAGE_REPO}", "backend", env.IMAGE_TAG)
          }
          dir('ui') {
            docker_build("${env.IMAGE_REPO}", "ui", env.IMAGE_TAG, "--build-arg BUILD_MODE=production")
          }
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Image Scan - Trivy') {
      steps {
        sh "echo '🔎 Running Trivy image scan...'"
        trivy_scan("${env.IMAGE_REPO}:backend-${env.IMAGE_TAG}")
        trivy_scan("${env.IMAGE_REPO}:ui-${env.IMAGE_TAG}")
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('DAST - OWASP ZAP (Baseline)') {
      steps {
        owasp_zap_scan(
          backendImage: "${env.IMAGE_REPO}:backend-${env.IMAGE_TAG}",
          scanDir: env.SCAN_DIR,
          targetUrl: "http://127.0.0.1:8081/api/reports",
          project: "ShieldOps",
          port: "8081"
        )
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Aggregate & Dashboard') {
      steps {
        sh '''
          echo "📊 Aggregating reports..."
          chmod +x aggregator/aggregate.sh || true
          bash aggregator/aggregate.sh "${SCAN_DIR}" || true
          chmod +x aggregator/make_dashboard.sh || true
          bash aggregator/make_dashboard.sh "${SCAN_DIR}"
        '''
        archiveArtifacts artifacts: 'reports/index.html', fingerprint: true
        script {
          try {
            publishHTML(target: [
              reportDir: 'reports',
              reportFiles: 'index.html',
              reportName: 'ShieldOps Security Dashboard',
              keepAll: true,
              alwaysLinkToLastBuild: true
            ])
          } catch (e) {
            echo "⚠️ HTML Publisher plugin not found — skipping dashboard publish."
          }
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Push Docker Images') {
      steps {
        script {
          docker_push("${env.IMAGE_REPO}", "backend-${env.IMAGE_TAG}")
          docker_push("${env.IMAGE_REPO}", "ui-${env.IMAGE_TAG}")
        }
      }
    }

    /* -------------------------------------------------------------------------- */
    stage('Deploy to Kubernetes (Helm)') {
      steps {
        script {
          try {
            helm_deploy(
              chartDir: './helm/ShieldOps',
              releaseName: 'shieldops',
              namespace: env.NAMESPACE,
              valuesFile: './helm/ShieldOps/values-ci.yaml',
              imageRepo: "${env.IMAGE_REPO}",
              imageTag: "backend-${env.IMAGE_TAG}",
              uiImageTag: "ui-${env.IMAGE_TAG}",
              timeout: '180s'
            )

            sh '''
              echo "🔎 Checking rollout status..."
              kubectl rollout status deployment/shieldops-backend --timeout=60s || (helm rollback shieldops && exit 1)
              kubectl rollout status deployment/shieldops-ui --timeout=60s || (helm rollback shieldops && exit 1)
            '''
          } catch (err) {
            sh "helm rollback shieldops || true"
            error("❌ Deployment failed — rollback executed.")
          }
        }
      }
    }
  }

  /* -------------------------------------------------------------------------- */
  post {

    success {
      def summary = """
        <b>ShieldOps Pipeline Success</b><br>
        Version: <b>${env.IMAGE_TAG}</b><br>
        All stages completed successfully.<br><br>
        Includes: SAST, SCA, Trivy, ZAP, Dashboard & Helm Deploy.
      """
      notify_email(env.EMAIL_RECIPIENT, "✅ ShieldOps Success • ${env.IMAGE_TAG}", summary)
    }

    unstable {
      def summary = """
        <b>ShieldOps Pipeline Warning</b><br>
        Build marked <b>UNSTABLE</b> due to quality gate warnings or scan issues.
      """
      notify_email(env.EMAIL_RECIPIENT, "⚠️ ShieldOps Warning", summary)
    }

    failure {
      def summary = """
        <b>ShieldOps Pipeline Failed</b><br>
        One or more stages failed.<br>
        Check Jenkins logs and dashboard for details.
      """
      notify_email(env.EMAIL_RECIPIENT, "❌ ShieldOps Failed • ${env.IMAGE_TAG}", summary)
    }

    always {
      archiveArtifacts artifacts: 'reports/**/*.{json,html,txt,sarif}', fingerprint: true
      cleanWs()
    }
  }
}
