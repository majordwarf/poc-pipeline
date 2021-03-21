pipeline {
	agent any
	stages {
		stage('Test Phase') {
			steps {
				echo "Testing code goes here..."
			}
		}

		stage('Build Phase') {
			steps {
				echo "Starting to build docker image..."
				sh '''
					docker build -t web-app:${BUILD_NUMBER} .
					docker tag web-app:${BUILD_NUMBER} 374163378991.dkr.ecr.ap-south-1.amazonaws.com/web-app:${BUILD_NUMBER}
				'''
			}
		}

		stage('Publish Phase') {
			steps {
				echo "Pushing the image to ECR..."
				sh '''
					aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 374163378991.dkr.ecr.ap-south-1.amazonaws.com
					docker push 374163378991.dkr.ecr.ap-south-1.amazonaws.com/web-app:${BUILD_NUMBER}
				'''
			}
		}

		stage('Kube Setup Phase') {
			steps {
				echo "Setting kubernetes context..."
				withAWS(region:'ap-south-1', credentials:'aws_iam_id') {
				sh '''
					aws eks --region ap-south-1 update-kubeconfig --name flask-app
					kubectl config use-context arn:aws:eks:ap-south-1:374163378991:cluster/flask-app
				'''
				}
			}
		}

		stage('Conditional Pod Count Check') {
			steps {
				withAWS(region:'ap-south-1', credentials:'aws_iam_id') {
					script {
						COUNT = sh script:'kubectl get deployments | tail -n +2 | wc -l', returnStdout: true 
						if(COUNT.toInteger() >= 5) {
							echo "Deployment exceeds nodes available.\nPlease purge existing idle deployments or add more nodes to the cluster."
							currentBuild.result = 'FAILURE'
							return
						}
					}
				}
			}
		}

		stage('Deploy latest image') {
			steps {
				sh '''
					sed "s/BUILD_NUMBER/\${BUILD_NUMBER}/g" ./deployment_config/app-controller-template.yml > ./app-controller.yml
					sed "s/BUILD_NUMBER/\${BUILD_NUMBER}/g" ./deployment_config/app-service-template.yml > ./app-service.yml
				'''
				withAWS(region:'ap-south-1', credentials:'aws_iam_id') {
					sh '''
						kubectl apply -f ./app-controller.yml
						kubectl apply -f ./app-service.yml
					'''
				}
				cleanWs()
			}
		}
	}
}
