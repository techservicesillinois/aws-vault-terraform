# UIUC Vault

[Vault](https://www.vaultproject.io/) is a product from Hashicorp for storing
and managing secrets. This project is a terraform configuration to deploy to AWS
a fully secured, highly available vault service configured for the UIUC
environment.

* [Design](#design)
    * [DNS](#design-dns)
    * [Storage: DynamoDB](#design-storage)
    * [Master Keys: Secrets Manager](#design-keys)
    * [Authentication: UOFI AD & AWS](#design-auth)
    * [Logging: CloudWatch Logs](#design-logging)
    * [Why Not Fargate?](#design-not-fargate)
* [Software Requirements](#software)
    * [Ansible](#software-ansible)
    * [AWS CLI](#software-awscli)
    * [Docker](#software-docker)
    * [SSH](#software-ssh)
    * [Terraform](#software-terraform)
* [Setup](#setup)
    * [AWS CLI](#setup-awscli)
    * [AWS VPC](#setup-awsvpc)
    * [SSH Key Pair: EC2](#setup-keypair)
    * [Terraform Locking: DynamoDB](#setup-terraform-dynamodb)
    * [Deployment Bucket: S3](#setup-deploy-bucket)
    * [SSL Certificate Files and AWS Certificate Manager](#setup-ssl)
    * [LDAP Authentication Bind](#setup-ldap)
* [Terraform Variables](#terraform-variables)
    * [Cloud First](#terraform-variables-cloudfirst)
    * [General](#terraform-variables-general)
    * [Vault Server](#terraform-variables-vaultserver)
    * [Vault Storage: DynamoDB](#terraform-variables-vaultstoragedyndb)
    * [Vault Storage: MariaDB](#terraform-variables-vaultstoragemariadb)
    * [Example](#terraform-variables-example)
* [Terraform Deploy](#terraform-deploy)
* [Post Deployment](#post-deployment)
    * [Auth: AWS](#post-deployment-auth-aws)
    * [Auth: Azure](#post-deployment-auth-azure)
    * [Secret Store: AD](#post-deployment-secret-ad)
* [Updates](#updates)
    * [EC2 Instances](#updates-ec2)
    * [Vault Server](#updates-vault-server)
    * [SSL Certificates](#updates-ssl)
* [TODO](#todo)


<a id="design"/>

## Design

Vault provides a Docker image that we will run on ECS, with one server per
availability zone to give high availability. Vault runs in a master/standby
configuration and not a load balanced configuration. This means that deploying
more servers does not give you more performance.

Connections made to a standby server will be forwarded on the backend to the
master. Some clients can also request that the standby server redirect them
to the master server. To support redirection, each server is directly accessible
without the load balancer.

<a id="design-dns"/>

### DNS

You will need to plan for the following hostnames, which will be registered
after the terraform is successfully run.

| Kind      | Resource      | Example                             | Description |
| --------- | ------------- | ----------------------------------- | ----------- |
| Primary   | Load Balancer | vault.example.illinois.edu          | This will be the primary endpoint for clients to contact. |
| Server A  | EC2 Instance  | server-a.vault.example.illinois.edu | Hostname for the server in Availability Zone A |
| Server B  | EC2 Instance  | server-b.vault.example.illinois.edu | Hostname for the server in Availability Zone B |

If you have more than two servers then expand the scheme appropriately.

<a id="design-storage"/>

### Storage: DynamoDB

Vault stores its data in DynamoDB, which is one of the highly available backends.
The DynamoDB Table is encrypted at rest by AWS and the data is individually
encrypted by Vault. Point In Time Recovery (PITR) is enabled on the table to
support rolling back the storage to a previous version.

<a id="design-keys"/>

### Master Keys: Secrets Manager

Each Vault server starts in a sealed state and needs several master keys to
unseal. This terraform stores those master keys in AWS Secrets Manager and
launches a helper to unseal a newly started Vault server. The master keys secret
is protected with its own AWS KMS Custom Key.

<a id="design-auth"/>

### Authentication: UOFI AD & AWS

You must provide a set of AD group names of people with admin access to the Vault
server. The first time this terraform is deployed it will configure Vault to
allow full access to these users, and also configure the EC2 instance to allow
SSH/sudo access. SSH access is given by public/private key authentication so
configure your admin users in AD with their SSH public keys.

**Some components require you to specify group names exactly the same as
they are specified in AD, including letter case.**

This terraform also enables AWS authentication which allows you to use AWS users
and roles to authenticate to Vault.

<a id="design-logging"/>

### Logging: CloudWatch Logs

Logs from the Docker containers will be stored in CloudWatch Logs. You can then
stream these logs to other systems, like Splunk. This terraform will also
enable Vault auditing and store those logs in CloudWatch Logs and on the EC2
instance the server is running on.

Two audit methods are used because Vault will not run with auditing enabled
unless at least one method is available. In case of a disaster most data on the
EC2 instance can be reconstructed using the terraform, however the audit logs
stored on the EC2 instance will be lost. You can recover them from CloudWatch
Logs.

CloudWatch Logs are encrypted at rest using the AWS KMS Custom key. The logs
on the instances are stored on encrypted EBS volumes using the AWS managed key.

<a id="design-not-fargate"/>

### Why Not Fargate?

Fargate is a new AWS serverless technology for running Docker containers. It was
considered for this project but rejected for several reasons:

1. No support for `IPC_LOCK`. Vault tries to lock its memory so that secret data
   is never swapped to disk. Although it seems unlikely Fargate swaps to disk, the
   lock capability is not provided.

2. Running on EC2 makes configuring Vault easier. The Ansible playbooks included
   with this terraform build the Vault configuration for each server. It would
   be much harder to do this in a Fargate environment with sidecar containers or
   custom Vault images.

3. Running on EC2 makes DNS configuration easier. The Vault redirection method
   means you need to know the separate DNS endpoint names and doing this on Fargate
   is complicated. With EC2 we register some ElasticIPs and use those for the
   individual servers.

Many of these problems could be solved by running Vault in a custom image. However,
it seemed valuable to use the Hashicorp Vault image instead of relying on custom
built ones, so EC2 was chosen as the ECS technology.


<a id="software"/>

## Software Requirements

This is an advanced terraform to deploy. You will need to have some
understanding of **Ansible**, **AWS CLI**, **Docker**, **Linux**, **SSH**, and
**terraform** before being able to use this terraform. This terraform uses
`local-exec` provisioners that assume a Linux environment with Ansible, AWS CLI,
and Docker available. You will need to install and configure several tools
before running the terraform.

Development of the terraform was done on macOS 10.13 using MacPorts provided
tools. It should be possible to use Windows Subsystems for Linux to deploy
this terraform. Some guesses at using WSL are provided, and you should
otherwise follow the Ubuntu 18.04 instructions.

Since Ansible and the AWS CLI are python projects it might be helpful to create
a virtual environment and install these tools inside of it. A `requirements.txt`
is provided for people who want to do this.

<a id="software-ansible"/>

### Ansible

Ansible must be available as the `ansible-playbook` command and version 2.4 or
newer. Older 2.x versions might work but have not been tested. Ansible is used
to configure the EC2 instances that will be launched.

You can use Ansible to keep the EC2 instances updated after deploying this
terraform.

<a id="software-ansible-macports"/>

#### MacPorts

```
sudo port install py36-ansible ansible_select
sudo port select --set ansible py36-ansible
```

<a id="software-ansible-ubuntu1804"/>

#### Ubuntu 18.04

```
sudo apt-get install ansible
```

<a id="software-awscli"/>

### AWS CLI

The AWS CLI must be available as the `aws` command and version 1.15.10 or newer.
Older versions might work but have not been tested. The AWS CLI is used to
launch ECS tasks to initialize vault.

<a id="software-awscli-macports"/>

#### MacPorts

```
sudo port install py36-awscli awscli_select
sudo port select --set awscli py36-awscli
```

<a id="software-awscli-ubuntu1804"/>

#### Ubuntu 18.04

```
sudo apt-get install awscli
```

<a id="software-docker"/>

### Docker

Docker must be available for the terraform provider to connect to. You
can run the daemon remotely and use `DOCKER_HOST` but it is easier to
run Docker Community Edition locally for your platform.

Terraform uses the docker daemon to lookup the image hashes for the ECS Tasks.
This makes sure that even if you use the `latest` tag you will still get
updates.

Downloads: [Docker for Mac](https://www.docker.com/docker-mac);
[Docker for Windows](https://www.docker.com/docker-windows).

<a id="software-docker-wsl"/>

#### Windows Subsystems for Linux

If you are using Docker for Windows and running the terraform in Windows
Subsystems for Linux then you need to set Docker to listen on `localhost:2375`.
Then from in the WSL terminal:

```
export DOCKER_HOST='tcp://localhost:2375'
```

You will need to set `DOCKER_HOST` for each new terminal you launch.

#### Other Platforms

Terraform will use the unix socket automatically to connect to the local
docker daemon.

<a id="software-ssh"/>

### SSH

Several of these tools will use SSH public/private key authentication to
connect to the EC2 instances. If you already have a key pair in AWS then you can
use that, but if not then you should generate one and store the private key on
the machine you'll use to run the terraform.

If you do not already have an SSH key then you can create one quickly. This
creates a key with a comment of "vault key" and no password. You will either
need to have no password for the key or add it to your SSH Agent for the
terraform to work.

```
mkdir ~/.ssh && chmod g=,o= ~/.ssh
ssh-keygen -t rsa -b 2048 -C 'vault key' -N '' -f ~/.ssh/vault
```

<a id="software-terraform"/>

### Terraform

Terraform must be available as the `terraform` command and version 0.11.7 or
newer. The most common place to place the binary is in `/usr/local/bin`.

[Terraform Download](https://www.terraform.io/downloads.html).


<a id="setup"/>

## Setup

A couple resources must exist before running the terraform. **Make sure to switch
to the "Ohio" region in the console before performing these steps!** The
Ohio region is coded into the terraform as the region to deploy to.

<a id="setup-awscli"/>

### AWS CLI

If you do not already AWS CLI configured then create an IAM user with
"programmatic access" only. For permissions attach the existing
"AdministatorAccess" policy. "PowerUserAccess" is not enough because this
terraform creates IAM roles and policies.

As the last step of creating the user you will download a CSV file with the access
key and secret access key. Run `aws configure` and use these values. For
default region us "us-east-2" (although the region is encoded in the terraform).

<a id="setup-awsvpc"/>

### AWS VPC

You will need a VPC that is peered with the Core Services VPC for LDAP
authentication to work. You do not need the campus subnets and VPN for
the terraform at this time.

[UIUC AWS VPC options and instructions.](https://answers.uillinois.edu/illinois/page.php?id=71015)

<a id="setup-keypair"/>

### SSH Key Pair: EC2

Take your existing SSH public key or the one you created earlier (`vault.pub`)
and import it as a Key Pair in the EC2 section. The name you give it during the
import will be used later when setting up the variables file.

<a id="setup-terraform-dynamodb"/>

### Terraform Locking: DynamoDB

Terraform uses a DynamoDB table to lock the remote state so that several people
working on the same terraform do not conflict. This is valuable even if a single
person is using the terraform since you might often work on multiple
workstations.

You can share the same table among multiple terraform projects. The easiest
thing to do is create a table called `terraform` with a partition key named
`LockID` (string).

<a id="setup-deploy-bucket"/>

### Deployment Bucket: S3

To bootstrap some of the resources secure materials must be stored in S3. This
bucket can also be used for storing the terraform remote state. Create a bucket
with versioning enabled and AES-256 encryption with the AWS managed key.

We suggest using the domain name of your Vault server as part of the bucket
name with the region as a suffix. For example, for a Vault server deployed
as "vault.example.illinois.edu" into Ohio the deployment bucket name might
be "deploy-vault.example.illinois.edu-us-east-2". This should make sure your
bucker name does not conflict with other buckets.

<a id="setup-ssl"/>

### SSL Certificate Files and AWS Certificate Manager

You will need an SSL SAN certificate with the primary and all server hostnames
in it. You can use a self-signed certificate or one issued by the campus
certificate manager.

You can create the key and certificate signing request with this command:

```
openssl req -new \
    -newkey rsa:2048 \
    -keyout server.key -keyform PEM -nodes \
    -out server.csr -outform PEM
# Country Name: US
# State or Province Name: Illinois
# Locality Name: Urbana
# Organization Name: University of Illinois
# Organizational Unit Name: Urbana-Champaign Campus
# Common Name: vault.example.illinois.edu (your primary name here)
# Email Address: blank
# Challenge Password: blank
# Company Name: blank
```

[Submit the request](https://go.illinois.edu/sslrequest) and include your server
domains in addition to the primary domain. For example, if your service will
be at "vault.example.illinois.edu" and you're running 2 servers then your request
will be:

* Certificate Type: Multi-Domain SSL
* FQDN of the server: vault.example.illinois.edu
* Additional domains: server-a.vault.example.illinois.edu,
  server-b.vault.example.illinois.edu
* HTTP Server Vendor: Other
* Certificate signing request: contents of the `server.csr` file
* Notes: Vault server

*Self-Signed or Private CA: left as an exercise for the reader.*

Once you've received your signed certificate back you need to construct a file
called `server.crt` with the signed certificate and the two InCommon
intermediary certificates:

```
(signed certificate contents)

-----BEGIN CERTIFICATE-----
MIIF+TCCA+GgAwIBAgIQRyDQ+oVGGn4XoWQCkYRjdDANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UE
BhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQK
ExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
dGlvbiBBdXRob3JpdHkwHhcNMTQxMDA2MDAwMDAwWhcNMjQxMDA1MjM1OTU5WjB2MQswCQYDVQQG
EwJVUzELMAkGA1UECBMCTUkxEjAQBgNVBAcTCUFubiBBcmJvcjESMBAGA1UEChMJSW50ZXJuZXQy
MREwDwYDVQQLEwhJbkNvbW1vbjEfMB0GA1UEAxMWSW5Db21tb24gUlNBIFNlcnZlciBDQTCCASIw
DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJwb8bsvf2MYFVFRVA+exU5NEFj6MJsXKZDmMwys
E1N8VJG06thum4ltuzM+j9INpun5uukNDBqeso7JcC7vHgV9lestjaKpTbOc5/MZNrun8XzmCB5h
J0R6lvSoNNviQsil2zfVtefkQnI/tBPPiwckRR6MkYNGuQmm/BijBgLsNI0yZpUn6uGX6Ns1oytW
61fo8BBZ321wDGZq0GTlqKOYMa0dYtX6kuOaQ80tNfvZnjNbRX3EhigsZhLI2w8ZMA0/6fDqSl5A
B8f2IHpTeIFken5FahZv9JNYyWL7KSd9oX8hzudPR9aKVuDjZvjs3YncJowZaDuNi+L7RyMLfzcC
AwEAAaOCAW4wggFqMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQe
BaN3j2yW4luHS6a0hqxxAAznODAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAd
BgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEC
AjBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNB
Q2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNo
dHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5jcnQwJQYIKwYB
BQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIBAC0RBjjW
29dYaK+qOGcXjeIT16MUJNkGE+vrkS/fT2ctyNMU11ZlUp5uH5gIjppIG8GLWZqjV5vbhvhZQPwZ
sHURKsISNrqOcooGTie3jVgU0W+0+Wj8mN2knCVANt69F2YrA394gbGAdJ5fOrQmL2pIhDY0jqco
74fzYefbZ/VS29fR5jBxu4uj1P+5ZImem4Gbj1e4ZEzVBhmO55GFfBjRidj26h1oFBHZ7heDH1Bj
zw72hipu47Gkyfr2NEx3KoCGMLCj3Btx7ASn5Ji8FoU+hCazwOU1VX55mKPU1I2250LoRCASN18J
yfsD5PVldJbtyrmz9gn/TKbRXTr80U2q5JhyvjhLf4lOJo/UzL5WCXEDSmyj4jWG3R7Z8TED9xNN
CxGBMXnMete+3PvzdhssvbORDwBZByogQ9xL2LUZFI/ieoQp0UM/L8zfP527vWjEzuDN5xwxMnhi
+vCToh7J159o5ah29mP+aJnvujbXEnGanrNxHzu+AGOePV8hwrGGG7hOIcPDQwkuYwzN/xT29iLp
/cqf9ZhEtkGcQcIImH3boJ8ifsCnSbu0GB9L06Yqh7lcyvKDTEADslIaeSEINxhO2Y1fmcYFX/Fq
rrp1WnhHOjplXuXE0OPa0utaKC25Aplgom88L2Z8mEWcyfoB7zKOfD759AN7JKZWCYwk
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIF3jCCA8agAwIBAgIQAf1tMPyjylGoG7xkDjUDLTANBgkqhkiG9w0BAQwFADCB
iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl
cnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV
BAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAw
MjAxMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCBiDELMAkGA1UEBhMCVVMxEzARBgNV
BAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVU
aGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2Vy
dGlmaWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
AoICAQCAEmUXNg7D2wiz0KxXDXbtzSfTTK1Qg2HiqiBNCS1kCdzOiZ/MPans9s/B
3PHTsdZ7NygRK0faOca8Ohm0X6a9fZ2jY0K2dvKpOyuR+OJv0OwWIJAJPuLodMkY
tJHUYmTbf6MG8YgYapAiPLz+E/CHFHv25B+O1ORRxhFnRghRy4YUVD+8M/5+bJz/
Fp0YvVGONaanZshyZ9shZrHUm3gDwFA66Mzw3LyeTP6vBZY1H1dat//O+T23LLb2
VN3I5xI6Ta5MirdcmrS3ID3KfyI0rn47aGYBROcBTkZTmzNg95S+UzeQc0PzMsNT
79uq/nROacdrjGCT3sTHDN/hMq7MkztReJVni+49Vv4M0GkPGw/zJSZrM233bkf6
c0Plfg6lZrEpfDKEY1WJxA3Bk1QwGROs0303p+tdOmw1XNtB1xLaqUkL39iAigmT
Yo61Zs8liM2EuLE/pDkP2QKe6xJMlXzzawWpXhaDzLhn4ugTncxbgtNMs+1b/97l
c6wjOy0AvzVVdAlJ2ElYGn+SNuZRkg7zJn0cTRe8yexDJtC/QV9AqURE9JnnV4ee
UB9XVKg+/XRjL7FQZQnmWEIuQxpMtPAlR1n6BB6T1CZGSlCBst6+eLf8ZxXhyVeE
Hg9j1uliutZfVS7qXMYoCAQlObgOK6nyTJccBz8NUvXt7y+CDwIDAQABo0IwQDAd
BgNVHQ4EFgQUU3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgEGMA8G
A1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEMBQADggIBAFzUfA3P9wF9QZllDHPF
Up/L+M+ZBn8b2kMVn54CVVeWFPFSPCeHlCjtHzoBN6J2/FNQwISbxmtOuowhT6KO
VWKR82kV2LyI48SqC/3vqOlLVSoGIG1VeCkZ7l8wXEskEVX/JJpuXior7gtNn3/3
ATiUFJVDBwn7YKnuHKsSjKCaXqeYalltiz8I+8jRRa8YFWSQEg9zKC7F4iRO/Fjs
8PRF/iKz6y+O0tlFYQXBl2+odnKPi4w2r78NBc5xjeambx9spnFixdjQg3IM8WcR
iQycE0xyNN+81XHfqnHd4blsjDwSXWXavVcStkNr/+XeTWYRUc+ZruwXtuhxkYze
Sf7dNXGiFSeUHM9h4ya7b6NnJSFd5t0dCy5oGzuCr+yDZ4XUmFF0sbmZgIn/f3gZ
XHlKYC6SQK5MNyosycdiyA5d9zZbyuAlJQG03RoHnHcAP9Dc1ew91Pq7P8yF1m9/
qS3fuQL39ZeatTXaw2ewh0qpKJ4jjv9cJ2vhsE/zB+4ALtRZh8tSQZXq9EfX7mRB
VXyNWQKV3WKdwrnuWih0hKWbt5DHDAff9Yk2dDLWKMGwsAvgnEzDHNb842m1R0aB
L6KCq9NjRHDEjf8tM7qtj3u1cIiuPhnPQCjY/MiQu12ZIvVS5ljFH4gxQ+6IHdfG
jjxDah2nGN59PRbxYvnKkKj9
-----END CERTIFICATE-----
```

*Self-Signed or Private CA: do not include the intermediary certificates listed
above. Instead, include your own CA certificate.*

Upload the `server.key`, `server.csr`, and `server.crt` files to the S3
deployment bucket. Make sure you follow this process:

* Set Permissions: **do not give public read**. The defaults should only list
  your own account. The terraform will give itself permissions to the bucket.
* Set Properties
    * Encryption: select "Amazon S3 master-key". Do not use a custom key to
      encrypt the files.
    * Header: add "Content-Type" as "text/plain". Make sure to **click "Save"**
      or your value might be ignored!

You will also need to import the certificate into AWS Certificate Manager (ACM).
The certificate in ACM is required for the load balancer.

* Certificate body: the contents of the signed certificate, excluding the
  intermediary certificates.
* Certificate private key: the content of `server.key`.
* Certificate chain: the intermediary certificates.

<a id="setup-ldap"/>

### LDAP Authenticated Bind

For configuring SSSD and Vault LDAP authentication we need an LDAP user to bind
to the directory for searching and reading attributes. You can create a new user
in your own OU or use an existing one appropriate for these purposes.

**Note: the LDAP user will need access to the memberOf attribute. You will need
to [request access to memberOf](https://answers.uillinois.edu/illinois/page.php?id=48115).**

Create a new text file called `ldap-credentials.txt` with this format. The file
should only have two lines where the first is a username format suitable for
binding (DN, Domain\\User, or User@FQDN) and the second is the password.

```
MyUserName@ad.uillinois.edu
MyRandomPassword
```

Upload the `ldap-credentials.txt` file to the S3 deployment bucket. Make sure
you follow this process:

* Set Permissions: **do not give public read**. The defaults should only list
  your own account. The terraform will give itself permissions to the bucket.
* Set Properties
    * Encryption: select "Amazon S3 master-key". Do not use a custom key to
      encrypt the file.
    * Header: add "Content-Type" as "text/plain". Make sure to **click "Save"**
      or your value might be ignored!


<a id="terraform-variables"/>

## Terraform Variables

It is helpful to create a "tfvars" file to store the variables for your
deployment. You can deploy multiple Vault servers by maintaining multiple
varfiles.

The examples for the variables will use the Tech Services Sandbox account
values. :exclamation: means the variable is required.

<a id="terraform-variables-cloudfirst"/>

### Cloud First

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| service :exclamation:                     |                                       | "Vault Example"                                                                       | The service name. For Tech Services this would be the name in the Service Catalog. This is available as a tag on resources. |
| contact :exclamation:                     |                                       | "vault-example@illinois.edu"                                                          | Email address to contact for problems. This address is set as the alias for root on the EC2 instances, but you shouldn't rely on these emails (AWS has limits and using a relay service isn't implemented yet). This is available as a tag on resources. |
| data_classification :exclamation:         |                                       | "Sensitive"                                                                           | The Illini Secure data classification. This should probably be "Sensitive" or "High Risk". This is available as a tag on storage resources. |
| environment                               | ""                                    | "Test"                                                                                | The environment: Development, Test, Staging, Production. Setting "Production" lengthens some of the retention periods of resources. This is available as a tag on resources. |
| project :exclamation:                     |                                       | "vault-exmp"                                                                          | Short, simple project name. Some resources have a "name" or "name prefix" and this will be used for that. |


<a id="terraform-variables-general"/>

### General

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| key_name :exclamation:                    |                                       | "Vault Example"                                                                       | Name of the EC2 Key Pair created earlier. |
| key_file :exclamation:                    |                                       | "~/.ssh/vault"                                                                        | Path to the SSH private key file on your local machine. |
| enhanced_monitoring                       | false                                 | true                                                                                  | Enable enhanced monitoring on EC2 and RDS instances created. |
| public_subnets :exclamation:              |                                       | \[ "techsvcsandbox-public1-a-net", "techsvcsandbox-public1-b-net" \]                  | List of names of public subnets. You should specify at least two for high availability. |
| private_subnets :exclamation:             |                                       | \[ "techsvcsandbox-private1-a-net", "techsvcsandbox-private1-b-net" \]                | List of names of private subnets. You should specify at least two for high availability. |
| campus_cidrs                              | (map of campus CIDR ranges)           |                                                                                       | The default list of campus CIDR ranges (UIUC, UA, and NCSA) when `ssh_allow_campus` and `app_allow_campus` are specified. If you override this you must provide all values. |
| ssh_allow_campus                          | true                                  | true                                                                                  | Allow anyone from a campus subnet range to SSH to the EC2 instances. |
| ssh_allow_cidrs                           | \[\]                                  | { "example" = \[ "123.123.231.321/32" \] }                                            | Map of list of CIDRs (subnet/bits) that should be allowed SSH access to the EC2 instances. The map keys are used in the rule descriptions. Use 'ssh_allow_campus' to include the campus ranges. |
| app_allow_campus                          | true                                  | true                                                                                  | Allow anyone from a campus subnet range to access the application ports. |
| app_allow_cidrs                           | \[\]                                  | { "example" = \[ "123.123.231.321/32" \] }                                            | Map of list of CIDRs (subnet/bits) that should be allowed access to the application ports. The map keys are used in the rule descriptions. Use 'app_allow_campus' to include the campus ranges. |
| deploy_bucket :exclamation:               |                                       | "deploy-vault.example.illinois.edu-us-east-2"                                         | Name of the bucket that contains the deployment resources (`server.key`, `server.crt`, `ldap-credentials.txt`). |
| deploy_prefix                             |                                       | "test/"                                                                               | Prefix of the resources inside the deployment bucket. This lets you use the same bucket for multiple deployments. If specified it must not begin with a "/" and must end with a "/". |
| vault_key_user_roles                      | \[\]                                  | \[ "TechServicesStaff" \]                                                             | List of IAM role names that are given access to the AWS KMS Custom Key protecting some of the resources. People with these roles will be able to read the master keys secret and the CloudWatch Logs. |

**Note: either both or one of `ssh_allow_campus` and `ssh_allow_cidrs` must be
specified. Either both or one of `app_allow_campus` and `app_allow_cidrs` must
be specified.**


<a id="terraform-variables-vaultserver"/>

### Vault Server

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| vault_server_admin_groups :exclamation:   |                                       | \[ "Admin Group 1", "Admin Group 2" \]                                                | List AD group names that will be given full access to SSH to the EC2 instance and manage the Vault server. Names specified here must mach AD exactly, including case. |
| vault_server_private_ips                  | \[\]                                  | \[ "10.224.255.51", "10.224.255.181" \]                                               | List of private IP addresses in the subnet. This is useful if you're carefully managing the private IP space of your VPC. Otherwise, AWS will choose unallocated IPs for you. If you specify this variable you must choose an IP for each subnet in the `public_subnets` list. |
| vault_server_fqdn                         | ""                                    | "vault.example.illinois.edu"                                                          | Primary FQDN of the vault server, present in the SSL certificate as the CN. |
| vault_server_public_fqdns :exclamation:   |                                       | \[ "server-a.vault.example.illinois.edu", "server-b.vault.example.illinois.edu" \]    | List of the FQDN of the vault server EC2 instances. You must specify a FQDN here for each subnet in the `public_subnets` variable. |
| vault_server_instance_type                | "t3.small"                            | "t3.medium"                                                                           | Instance type to use for the vault servers; do not use smaller than t3.micro. |
| vault_server_image                        | "vault:latest"                        | "vault:0.10.3"                                                                        | Docker image to use for the vault server. If you use the "latest" tag then each run of the terraform will make sure the image is the most current. Production might want to use a specific version tag. |
| vault_helper_image                        | "sbutler/uiuc-vault-helper:latest"    | "sbutler/uiuc-vault-helper:latest"                                                    | Docker image to use for the vault helper. If you use the "latest" tag then each run of the terraform will make sure the image is the most current. Production might want to use a specific version tag. |
| vault_storage                             | \[ "dynamodb" \]                      | \[ "mariadb" \]                                                                       | List of storage backends to provision with terraform. The first will be used as the primary, the others unused by vault server. Multiple backends are useful for doing migrations between them. Supported values: dynamodb, mariadb |

**Note:** for performance reasons on DynamoDB the initialization
helper disables periodic cleanup of the AWS Identity Whitelist and
Role Tag Blacklist. If you are using a storage backend other than
DynamoDB then you should enable these features.


<a id="terraform-variables-vaultstoragedyndb"/>

### Vault Storage: DynamoDB

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| vault_storage_dyndb_max_parallel          | 128                                   | 256                                                                                   | Maximum number of parallel operations vault will perform with the DynamoDB backend.


<a id="terraform-variables-vaultstoragemariadb"/>

### Vault Storage: MariaDB

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| vault_storage_mariadb_version             | "10.2"                                | "10.0"                                                                                | Version of the database engine to use, major and minor. Do not specify patch levels so that automatic maintenance happens. |
| vault_storage_mariadb_class               | "db.t3.small"                         | "db.t3.medium"                                                                        | RDS instance class to use. |
| vault_storage_mariadb_size                | 5                                     | 20                                                                                    | Size of the storage to attach, in GB. This value must be at least "5" and AWS recommends at least "20". |
| vault_storage_mariadb_max_parallel        | 0                                     | 130                                                                                   | Maximum number of parallel operations to perform. This should not be more than the max_connections setting. If 0 then the terraform choose a value that's 90% of the max_connections. |
| vault_storage_mariadb_admin_username      | "vault_admin"                         | "my_admin"                                                                            | Name of the administrator user for the database when provisioning. The password is randomly generated. |
| vault_storage_mariadb_app_username        | "vault_server"                        | "example_server"                                                                      | Name of the application user that vault server will use to connect to the database. The password is randomly generated. |
| vault_storage_mariadb_backup_retention    | 30                                    | 90                                                                                    | Number of days to retain database snapshots. |
| vault_storage_mariadb_backup_window       | "09:00-10:00"                         | "09:00-10:00"                                                                         | Window to perform daily backups, in UTC. This must not overlap with the maintenance window. |
| vault_storage_mariadb_maintenance_window  | "Sun:07:00-Sun:08:00"                 | "Mon:11:00-Mon:12:00"                                                                 | Window to perform weekly maintenance, in UTC. This must not overlap with the backup window. |


<a id="terraform-variables-example"/>

### Example

Construct a file in `varfiles` with your variable choices. Using the
examples above we might have a `varfiles/example.tfvars` that looks
like this:

```
service = "Vault Example"
contact = "vault-example@illinois.edu"
data_classification = "Sensitive"
environment = "Test"

project = "vault-exmp"
key_name = "Vault Example"
key_file = "~/.ssh/vault"
enhanced_monitoring = true
public_subnets = [
    "techsvcsandbox-public1-a-net",
    "techsvcsandbox-public1-b-net",
]
deploy_bucket = "deploy-vault.example.illinois.edu-us-east-2"
deploy_prefix = "test/"

vault_key_user_roles = [
    "TechServicesStaff",
]
vault_server_admin_groups = [
    "Admin Group 1",
    "Admin Group 2",
]
vault_server_private_ips = [
    "10.224.255.52",
    "10.224.255.182",
]
vault_server_fqdn = "vault.example.illinois.edu"
vault_server_public_fqdns = [
    "server-a.vault.example.illinois.edu",
    "server-b.vault.example.illinois.edu",
]
vault_server_instance_type = "t3.medium"
vault_server_image = "vault:latest"
vault_helper_image = "sbutler/uiuc-vault-helper:latest"
```


<a id="terraform-deploy"/>

## Terraform Deployment

Now that everything has been setup, with our local and remote
environments prepared, we're ready to deploy with the terraform
configuration. All of these steps take place in the `terraform`
directory.

You will need to edit the `_providers.tf` file and change some of
the settings. There are some things that happen early in the terraform
process so we can't use variables for them. Find this block:

```
terraform {
    required_version = "~> 0.11.7"

    backend "s3" {
        bucket = "deploy-vault.example.illinois.edu-us-east-2"
        key = "terraform/state"
        dynamodb_table = "terraform"

        encrypt = true

        region = "us-east-2"
    }
}
```

Review and update these parameters. Do not use the example value
given for `bucket`:

* `bucket`: set this to the same name as your deployment bucket,
  unless you already have an S3 bucket setup to store terraform state.
  Using the deployment bucket here should always be acceptable. In
  our example a good value might be "deploy-vault.example.illinois.edu-us-east-2".
* `key`: this is the name of the remote state as stored in the
  bucket. If you've chosen a deployment prefix above then you should
  probably use that here along with "terraform/state". In our example
  a good value might be "test/terraform/state".
* `dynamodb_table`: name of the table we created earlier for
  terraform locking. If you followed the example then "terraform" is
  an acceptable value.

*WSL: remember to run `export DOCKET_HOST='tcp://localhost:2375'` in
your terminal*

The first time you run a terraform or after any updates (`git pull`)
you should always re-initialize it.

```
terraform init
```

That should tell you that terraform has been successfully initialized.
If you see any errors you need to stop and resolve them before
continuing. Sometimes deleting the `.terraform` directory can help if
you're moving between accounts or change the remote state configuration.

Next step is to ask terraform to build a plan of our changes. If we
use the example variable file above then this command looks like:

```
terraform plan \
    -var-file varfiles/example.tfvars \
    -out changes.tfplan
```

You should see a long list of resources to be created if this is your
first time running it, or a list of resources to be changed/deleted
if you're performing updates. Take a look and verify that the plan
makes sense.

*Note: all critical resources in the terraform should be protected
against deletion. You shouldn't be able to accidentally delete something
that's not recoverable.*

If the plan looks OK then run the command to apply it:

```
terraform apply changes.tfplan
```

After a time this should complete successfully and output some basic
information about the resources it created. If you see errors then
resolve them and re-run the `terraform plan` and `terraform apply`
commands.

Once terraform successfully completes you now have your Vault server!


<a id="post-deployment"/>

## Post Deployment

Now that you have IP's and hostnames you can finish setting up the DNS
records in IPAM. If you no longer have the output of `terraform apply`
then run `terraform output` to get these values:

* `vault_server_lb`: create a CNAME record from your primary domain to
  this hostname. It must be a CNAME record since AWS frequently changes
  the IPs of the load balancers.
* `vault_server_public_ips`: you will get one IP for each EC2 instance
  running Vault. Create the A records for the IPs in this list. The
  first IP in this list corresponds to the first entry in
  `vault_server_public_fqdns`, the second the second entry, etc.

Once the DNS changes are available you should be able to visit your
server at its primary domain on port 8200. For example,
https://vault.example.illinois.edu:8200/ui/. If you are using the
Vault CLI then the `VAULT_ADDR` variable would be
`https://vault.example.illinois.edu:8200/` (without the `/ui` portion).

Select "LDAP" for the authentication method and log in with a user
in one of your admin groups. The Vault UI is fairly complete for basic
operations but you might want to familiarize yourself with the Vault
CLI for administration.

You should also be able to SSH to the EC2 instances with a user in
your admin groups. SSH will alway use public key authentication so
if you haven't already then add your SSH public keys to LDAP. You can
do this using the "My.Engineering" portals for your department or, for
OU managed accounts, add the `uiucEduSSHPublicKey` attribute. You might
also want to set your `loginShell` while you're there.

*If SSH as your admin user isn't working then you can use the `ec2-user`
with the SSH private key we created for this terraform.*

You should also take a moment to find your logs in CloudWatch Logs.
You can see a lot of information about what Vault is doing in the
"/$project/ecs-containers/vault-server" log group.

<a id="post-deployment-auth-aws"/>

### Auth: AWS

This terraform configuration will setup all the permissions and roles
required to authenticate resources in the same account as the vault
server. For resources in different accounts you will need to mount
the AWS Auth method at a different path, create an IAM user, and use
the access_key and secret_key in the [AWS Auth configuration](https://www.vaultproject.io/api/auth/aws/index.html).

<a id="post-deployment-auth-azure"/>

### Auth: Azure

Resources in Azure can use Managed Service Identity (MSI) to
authenticate to vault, much like how resources in AWS can use IAM Users
and Roles. You will need to find two pieces of information present in
your account:

* Subscription ID: this is under "All Services", "Subscriptions". If
  you have multiple subscriptions then you will need to setup multiple
  Azure authentication mounts.
* Tenant ID: this is under "All Services", "Azure Active Directory",
  "Properties", and it is the value in the "Directory ID" field.

The vault server will need some permissions to read virtual machines
in your subscription. You could use the "Reader" role but this gives
many more permissions than required. You should [create a custom role](https://docs.microsoft.com/en-us/azure/role-based-access-control/custom-roles)
called "Vault Server Reader" with this document:

```
{
    "Name": "Vault Server Reader",
    "IsCustom": true,
    "Description": "Lets the vault server read the items it needs.",
    "Actions": [
        "Microsoft.Compute/virtualMachines/*/read",
        "Microsoft.Compute/virtualMachineScaleSets/*/read"
    ],
    "NotActions": [],
    "DataActions": [],
    "NotDataActions": [],
    "AssignableScopes": [
         "/subscriptions/${subscription_id}"
     ]
}
```

If you have multiple subscriptions then you can list each one in the
`AssignableScopes` value.

Register the application that Vault will use to authenticate to Azure:

1. Under "All Services", "Azure Active Directory", "App Registrations".
2. "New application registration".
    * Name: something simple and descriptive for your vault server.
      Example: `mygroup-vault-server`.
    * Application type: `Web app / API`.
    * Sign-on URL: this should be the URL to the vault server UI.
      Example: `https://vault.example.illinois.edu:8200/ui`.
3. Under "Settings" for the new application:
    * Properties:
        * Application ID: this is the `client_id`.
        * App ID URI: this is the `resource`.
    * Keys:
        1. Add a new "Password" key by entering something in the
           "Description" column, choosing a duration, and then clicking
           "Save".
        2. The "Value" column will show the `client_secret` only once,
           right after clicking "Save". Copy this value for use later.
4. Under "All Services", "Subscriptions" click on the subscription you
   use for resources.
    1. Click "Access control (IAM)".
    2. Click "Add".
        * Role: select the "Vault Server Reader" role we created above,
          or the provided "Reader" role.
        * Assign access to: `Azure AD user, group, or application`.
        * Select: type the name of the application you registered. It
          should appear in the list. Select it.
    3. Click "Save". You should now see the application with the correct
       role.

We can now use these values to enable and configure the Azure auth
method in vault. If you might have multiple, independent subscriptions
you're connecting the Azure method to then you might want to enable it
at different paths.

```
vault auth enable azure
vault write auth/azure/config \
    tenant_id=(Tenant ID/Directory ID) \
    resource=(App ID URI) \
    client_id=(Application ID) \
    client_secret=(Password Key Value)
```

Then you can create roles for Azure MSI to use to authenticate. Some
parameters that roles can have to limit their use:

* bound_service_principal_ids
* bound_group_ids
* bound_location
* bound_subscription_ids
* bound_resource_group_names
* bound_scale_sets

The vault CLI does not have a nice way to authenticate using Azure MSI
at the moment. The included `uiuc-vault-azure-login` script should help
make this easier.

<a id="post-deployment-secret-ad"/>

### Secret Store: AD

Vault can be used to automatically store and rotate AD passwords. You
will need an AD service user with permissions to reset/change the
password for the users you want to manage in vault. If you are going to
use multiple AD service users then you should mount the secret store at
different paths for each.

Notes on the values used to [configure the AD secret store](https://www.vaultproject.io/docs/secrets/ad/index.html):

| Parameter    | Value                                | Notes |
| ------------ | ------------------------------------ | ----- |
| url          | ldap://ldap-ad-aws.ldap.illinois.edu | The AWS LDAP load balancer. |
| starttls     | true                                 | Use StartTLS since SSL is not supported on the AWS load balancer. |
| insecure_tls | false                                |  |
| certificate  | @path/to/incommon.pem                | Specify the path to a file that stores only the "[AddTrust External CA Root](http://certmgr.techservices.illinois.edu/technical.htm)". Doing it this way will make sure certificate renewals go smoothly as long as InCommon uses the same root certificate. |
| binddn       | CN=LDAPAdminUser,OU=...              | The full DN to the AD service user with permissions to reset/change passwords. |
| bindpass     | SomethingSecret                      | Password for the AD service user. You can use the `/ad/rotate-root` endpoint to rotate this password later if you want, which makes the password only known to vault. |
| userdn       | DC=ad,DC=uillinois,DC=edu            | It should be safe to specify the directory naming root, but you can also specify the DN to some other OU to further limit which users can have their passwords managed. |

When creating roles for the AD secret store the `service_account_name`
must be the `userPrincipalName` of the account whose password will be
managed. For example, `Vault-Example1@ad.uillinois.edu`.


<a id="updates"/>

## Updates

There are several components of the vault infrastructure you will need
to keep up to date.

<a id="updates-ec2"/>

### EC2 Instances

The Vault servers are the ECS Optimized Amazon Linux image. You can
update them with simple Ansible playbooks or by using the `yum update`
command.

Updates to the terraform Ansible will also apply on the next run of
the terraform.

<a id="updates-vault-server"/>

### Vault Server

If you are using the "vault:latest" image for the server then you will
get updates the next time you run terraform. If you are using a specific
tag then you will need to change the version in the tag yourself to
get updates.

<a id="updates-ssl"/>

### SSL Certificates

When its time to renew your certificates you follow the same basic
steps as when you first requested them. You can use the same `server.csr`
file to request the renewal.

After you get your signed certificate back you will need to update it
in two places:

1. AWS Certificate Manager (ACM): find the certificate you imported
   and [reimport it](https://docs.aws.amazon.com/acm/latest/userguide/import-reimport.html).
2. Deployment Bucket: build a new `server.crt` file and upload it using
   the same process to the deployment bucket. When you next run the
   terraform apply/plan commands it should detect the change and reload
   the Vault servers.


<a id="todo"/>

## TODO

Things it would be nice to add:

1. Monitoring and notifications using CloudWatch.
    - Docker container stops/starts.
    - Host CPU usage.
    - Host disk space.
2. Restructure for Fargate.
    - Verify `IPC_LOCK` isn't required.
    - Custom image to do unseal/init.
    - Update hostnames with public IPs.
3. SAML authentication plugin. Requires custom Vault development.
