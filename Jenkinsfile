@Library('JenkinsSharedLibs') _

pipeline {
  agent any

  environment {
    REGISTRY        = "docker.io/${REGISTRY}/ShieldOps"
    IMAGE_NAME      = "shieldops"
    NAMESPACE       = "shieldops"
    SCAN_DIR        = "${WORKSPACE}/reports"
    EMAIL_RECIPIENT = "email.example@gmail.com"
    PATH            = "/usr/local/bin:/usr/bin:/bin:/home/ubuntu/.local/bin:${PATH}"
    ODC_CACHE_DIR   = "/tmp/odc-data"
  }

  stages {

    stage('Clean Workspace') {
      steps { cleanWs() }
    }

    stage('Checkout Code') {
      steps {
        echo "🔄 Cloning ShieldOps repository..."
        git branch: 'main', url: 'https://github.com/${REGISTRY}/ShieldOps.git'
      }
    }

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
          which codeql >/dev/null 2>&1 || echo "⚠️ CodeQL not installed; skipping."
        '''
      }
    }

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

    stage('Build UI (Vite)') {
      steps {
        dir('ui') {
          sh '''
            echo "VITE_API_BASE_URL=/api" > .env
            npm install --no-audit --legacy-peer-deps
            if ! npx vite --version >/dev/null 2>&1; then
              echo "vite not found — installing locally..."
              npm install vite --save-dev --no-audit --legacy-peer-deps
            fi
            npx vite build
          '''
        }
      }
    }

    stage('SAST - ESLint, Bandit & CodeQL') {
      steps {
        script {
          dir('ui') {
            sh '''
              if [ -f "../reports/eslint-report.json" ]; then rm -f ../reports/eslint-report.json; fi
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

    stage('SCA - Dependency-Check, Safety & CycloneDX') {
      parallel {
        stage('Backend SCA') {
          steps {
            script {
              owasp_dependency_check(
                scanPath : 'backend',
                reportDir: env.SCAN_DIR,
                project  : 'ShieldOps-backend',
                cacheDir : env.ODC_CACHE_DIR,
                additionalArgs: '--exclude **/node_modules/** --exclude **/test/** --exclude **/dist/** --failOnCVSS 9'
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
                scanPath : 'ui',
                reportDir: env.SCAN_DIR,
                project  : 'ShieldOps-ui',
                cacheDir : env.ODC_CACHE_DIR,
                additionalArgs: '--exclude **/node_modules/** --exclude **/dist/**'
              )
              dir('ui') {
                sh 'npx -y @cyclonedx/bom -o ../reports/bom-frontend.json || true'
              }
            }
          }
        }
      }
    }

    stage('Build Docker Images') {
      steps {
        script {
          docker_build("${env.REGISTRY}/${env.IMAGE_NAME}", "backend", "backend")
          docker_build("${env.REGISTRY}/${env.IMAGE_NAME}", "ui", "ui")
        }
      }
    }

    stage('Image Scan - Trivy') {
      steps {
        sh "echo '🔎 Running Trivy image scan...'"
        trivy_scan("${env.REGISTRY}/${env.IMAGE_NAME}:backend")
        trivy_scan("${env.REGISTRY}/${env.IMAGE_NAME}:ui")
      }
    }

    stage('DAST - OWASP ZAP (Baseline)') {
      steps {
        owasp_zap_scan(
          backendImage: "${env.REGISTRY}/${env.IMAGE_NAME}:backend",
          scanDir     : env.SCAN_DIR,
          targetUrl   : "http://127.0.0.1:8081/api/reports",
          project     : "ShieldOps",
          port        : "8081"
        )
      }
    }

    stage('Aggregate Reports') {
      steps {
        sh '''
          echo "📊 Aggregating reports..."
          chmod +x aggregator/aggregate.sh || true
          bash aggregator/aggregate.sh "${SCAN_DIR}" || true
        '''
        generate_reports('reports')
      }
    }

    stage('Generate HTML Dashboard') {
      steps {
        sh '''
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

    stage('Push Docker Images') {
      steps {
        script {
          docker_push(imageName: "${env.REGISTRY}/${env.IMAGE_NAME}", imageTag: "backend")
          docker_push(imageName: "${env.REGISTRY}/${env.IMAGE_NAME}", imageTag: "ui")
        }
      }
    }

    stage('Deploy to Kubernetes (Helm)') {
      steps {
        script {
          try {
            helm_deploy(
              chartDir   : './helm/ShieldOps',
              releaseName: 'shieldops',
              namespace  : env.NAMESPACE,
              valuesFile : './helm/ShieldOps/values-ci.yaml',
              imageRepo  : "${env.REGISTRY}/${env.IMAGE_NAME}",
              imageTag   : "backend",
              uiImageTag : "ui",
              timeout    : '180s'
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

  post {
    always {
      archiveArtifacts artifacts: 'reports/**/*.{json,html,txt,sarif}', fingerprint: true
    }

    success {
      notify_email(
        env.EMAIL_RECIPIENT,
        '✅ ShieldOps Pipeline Success',
        'All stages completed successfully — SAST, SCA, Trivy, ZAP, Dashboard, Helm deploy, and reports generated.'
      )
    }

    failure {
      notify_email(
        env.EMAIL_RECIPIENT,
        '❌ ShieldOps Pipeline Failed',
        'One or more stages failed. Please check Jenkins logs for details.'
      )
    }

    cleanup { cleanWs() }
  }
}
