<h1 align="center">🔵🟢 Blue Green Deployment Pipeline</h1>

---

<p align="center">
  <a href="#definitions">🢝 Definitions</a>&nbsp;&nbsp;
  <a href="#info">🢝 Info</a>&nbsp;&nbsp;
  <a href="#setup">🢝 Setup</a>&nbsp;&nbsp;
  <a href="#pipeline">🢝 Pipeline</a>
  <br />
  <a href="http://15.206.73.216:8080/">ᐅ Jenkins</a>&nbsp;&nbsp;
  <a href="http://a17ad71a36bf24e3c961b38f2dbc96a4-1675089812.ap-south-1.elb.amazonaws.com:5000">ᐅ Deployed App</a>
</p>

---

## Definitions

```
EC2 - Elastic Compute 2
ECR - Elastic Container Registry
EKS - Elastic Kuberenetes Service
```

## Info

The following project utilizes the Blue-Green deployment strategy to deploy a flask application wrapped inside a docker image to EKS. The pipeline initially creates a docker image tagged with the build number in Jenkins to easily track multiple versions and push them to ECR. Later the image is deployed to EKS for the service to route to the newer version.

#### Project Structure:

```
├── app/               - Contains the main application to be deployed
├── deployment_config/ - Services and controllers for k8s deployment
├── etc/               - Source code for other pipelines
├── Dockerfile         - Instructions to build docker image
└── Jenkinsfile        - Main pipeline to deploy the blue version to EKS
```

---

## Setup

#### Deployment Lifecycle:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│ (Local System) ──PUSH──> (Git Server) ──WEBHOOK──> (EC2 Jenkins Server) │
│                                                             │           │
│                                                 ┌──>   Build Image      │
│                                                 │           │           │
│                                                 │   Push Image to ECR   │
│                                     Pipeline -> │           │           │
│                                                 │      Deployment       │
│                                                 │           │           │
│                                                 └──> Re-route Service   │
│                                                             │           │
│                                                             ˅           │
│                                                    (Kubernetes Cluster) │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

- **Blue-Green Strategy**
  - Before we get into detail about technical setup, let's get over the `Blue-Green` deployment strategy.
  - It is a technique that reduces downtime by having two production environments, while one serves traffic one stays idle.
  - When a new version is available it is pushed to the idle environment and the traffic is routed to the new version
  - If a bug is discovered in the new version, the routing can be rolled back to the old version.
  - But with the availability of container technology and app scaling methods, we can deploy multiple versions of the app at a time, deallocate them as wanted and load-balance them as needed.
  - The current pipeline can support having multiple versions to roll back and the deployments can be removed if not needed.

---

- **Setting Up Jenkins**
  - Provision a linux server `[EC2 Instance t2.micro]` with the following packages installed for our Jenkins server. 
    - jenkins
    - docker
    - aws-cli
    - kubeclt
    - eksclt
  - Set up an IAM role with proper permissions for the instance to communicate with other AWS services without the use of the IAM User's `access id` and `secret key`.
  - Add security inbound rule to expose Jenkins server port `[8080 in this case]` to public.
  - Configure Jenkins to enable viewing Jobs without authentication.
  - Install Jenkins plugin, `aws-pipeline` to access AWS services if Jenkins is hosted outside AWS environment.
  - Create IAM User with proper permissions and store its `ACCESS_ID` and `SECRET_KEY` as credentials inside Jenkins.
  - Create a new pipeline job as `Pipeline script from SCM` attaching Git repository.
  - Setup the Git repository with webhook to send `PUSH` notifications to the Jenkins server.

---

- **EKS Cluster**
  - Version 1.19
  - Nodes 5
  - Node-type t2.micro
  - Node-ami auto
  - Region ap-south-1

We provision a Kubernetes cluster with the above specs, the maximum nodes can be adjusted as per the needs. The following can be automated using any of the Infrastructure as Code (IaC) provisioning tools available like CloudFormation and Terraform.

---

## Pipeline

We use three different pipelines to automate our workflow. The `main` pipeline is fully automated to be executed when a new version is pushed to our git repository. The `routing` pipeline is used to switch routes between any version existing on our cluster. The `purge` pipeline is used to delete all inactive/idle deployments.

#### Main Pipeline

- The pipeline begins by having a test phase. This is currently empty but can be modified as per the organization's need.
- Once testing is done, we build and tag the docker image via the `Dockerfile` present in the root of the project directory.
- Each image build is tagged with its Jenkins build number to keep track of them easily.
- Once the following is done, we fetch ECR credentials via `aws-cli`. This is the preferred method when accessing AWS services via their internal VPC. This reduces the task of storing credentials on the server.
- We use the credential to log into our ECR repository and then push the built image there.
- Next, we utilize the `aws-pipeline` plugin, which can be used when accessing AWS services from outside their VPC. Here we utilize the stored IAM credential and setup Kubernetes configuration.
- Once the configuration is done, we check if the current deployment exceeds the nodes available.
- We terminate the pipeline if the nodes are at their maximum capacity.
- If we still have empty nodes to deploy, we use the current docker image build from ECR to be deployed on the node.
- Once the node is up, we re-route the service to the new node.
- The config for the above two steps is store as a template in `YAML` format, we modify it during the build as per the build number.
- The old node continues to exist in case we discover a bug in the latest build.
- After everything is done, we clean up the environment, this is necessary as we are directly working on our Jenkins server, not ephemeral agents.

---

#### Purging Pipeline

- Use IAM credentials to authenticate with the EKS cluster.
- Fetch the active service which is being served via the load-balancer.
- Fetch the list of all deployments on the cluster.
- Delete all inactive/idle deployments.

---

#### Routing Pipeline

- Use IAM credentials to authenticate with the EKS cluser.
- Fetch the active service which is being served via the load-balancer.
- Fetch the list of all deployments on the cluster.
- Ask the user for input to select which version to set routing.
- Switch routing to the specified version.

---

<h4 align="center">End 👋</h1>