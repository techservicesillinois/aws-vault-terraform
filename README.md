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
    * [SSH Key Pair: EC2](#setup-keypair)
    * [Terraform Locking: DynamoDB](#setup-terraform-dynamodb)
    * [Deployment Bucket: S3](#setup-deploy-bucket)
    * [SSL Certificate Files and AWS Certificate Manager](#setup-ssl)
    * [LDAP Authentication Bind](#setup-ldap)
* [Terraform Variables](#terraform-variables)
* [Terraform Deploy](#terraform-deploy)
* [Post Deployment](#post-deployment)
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
SSH/sudo access. SSH access is given by public/private key authentication, so
configure your admin users in AD with their SSH public keys.

**Not all components are configured to support nested groups. For best results
make sure that your admin groups have direct members and not nested members.**

This terraform also enables AWS authentication which allows you to use AWS users
and roles to authenticate.

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
on the instances are stored on encrypted EBS volumes using the AWS provided key.

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

Docker must be available as the `docker` command locally. You can run the daemon
remotely and use `DOCKER_HOST` but it is easier to run Docker Community Edition
locally for your platform.

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
newer.

[Terraform Download](https://www.terraform.io/downloads.html).


<a id="setup"/>

## Setup

A couple resources must exist before running the terraform. **Make sure to switch
to the "Ohio" region in the console before performing these steps!**

<a id="setup-awscli"/>

### AWS CLI

If you do not already AWS CLI configured then create an IAM user with
"programmatic access" only. For permissions attached the existing
"AdministatorAccess" policy. "PowerUserAccess" is not enough because this
terraform creates IAM roles and policies.

As the last step of creating the user you will get a CSV file with the access
key and secret access key. Run `aws configure` and use these values. For
default region us "us-east-2" (although the region is encoded in the terraform).

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
MIIF+TCCA+GgAwIBAgIQRyDQ+oVGGn4XoWQCkYRjdDANBgkqhkiG9w0BAQwFADCB
iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl
cnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV
BAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTQx
MDA2MDAwMDAwWhcNMjQxMDA1MjM1OTU5WjB2MQswCQYDVQQGEwJVUzELMAkGA1UE
CBMCTUkxEjAQBgNVBAcTCUFubiBBcmJvcjESMBAGA1UEChMJSW50ZXJuZXQyMREw
DwYDVQQLEwhJbkNvbW1vbjEfMB0GA1UEAxMWSW5Db21tb24gUlNBIFNlcnZlciBD
QTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJwb8bsvf2MYFVFRVA+e
xU5NEFj6MJsXKZDmMwysE1N8VJG06thum4ltuzM+j9INpun5uukNDBqeso7JcC7v
HgV9lestjaKpTbOc5/MZNrun8XzmCB5hJ0R6lvSoNNviQsil2zfVtefkQnI/tBPP
iwckRR6MkYNGuQmm/BijBgLsNI0yZpUn6uGX6Ns1oytW61fo8BBZ321wDGZq0GTl
qKOYMa0dYtX6kuOaQ80tNfvZnjNbRX3EhigsZhLI2w8ZMA0/6fDqSl5AB8f2IHpT
eIFken5FahZv9JNYyWL7KSd9oX8hzudPR9aKVuDjZvjs3YncJowZaDuNi+L7RyML
fzcCAwEAAaOCAW4wggFqMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bL
MB0GA1UdDgQWBBQeBaN3j2yW4luHS6a0hqxxAAznODAOBgNVHQ8BAf8EBAMCAYYw
EgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUH
AwIwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAECAjBQBgNVHR8ESTBHMEWgQ6BB
hj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNh
dGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNo
dHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQWRkVHJ1c3RDQS5j
cnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
hvcNAQEMBQADggIBAC0RBjjW29dYaK+qOGcXjeIT16MUJNkGE+vrkS/fT2ctyNMU
11ZlUp5uH5gIjppIG8GLWZqjV5vbhvhZQPwZsHURKsISNrqOcooGTie3jVgU0W+0
+Wj8mN2knCVANt69F2YrA394gbGAdJ5fOrQmL2pIhDY0jqco74fzYefbZ/VS29fR
5jBxu4uj1P+5ZImem4Gbj1e4ZEzVBhmO55GFfBjRidj26h1oFBHZ7heDH1Bjzw72
hipu47Gkyfr2NEx3KoCGMLCj3Btx7ASn5Ji8FoU+hCazwOU1VX55mKPU1I2250Lo
RCASN18JyfsD5PVldJbtyrmz9gn/TKbRXTr80U2q5JhyvjhLf4lOJo/UzL5WCXED
Smyj4jWG3R7Z8TED9xNNCxGBMXnMete+3PvzdhssvbORDwBZByogQ9xL2LUZFI/i
eoQp0UM/L8zfP527vWjEzuDN5xwxMnhi+vCToh7J159o5ah29mP+aJnvujbXEnGa
nrNxHzu+AGOePV8hwrGGG7hOIcPDQwkuYwzN/xT29iLp/cqf9ZhEtkGcQcIImH3b
oJ8ifsCnSbu0GB9L06Yqh7lcyvKDTEADslIaeSEINxhO2Y1fmcYFX/Fqrrp1WnhH
OjplXuXE0OPa0utaKC25Aplgom88L2Z8mEWcyfoB7zKOfD759AN7JKZWCYwk
-----END CERTIFICATE-----

-----BEGIN CERTIFICATE-----
MIIFdzCCBF+gAwIBAgIQE+oocFv07O0MNmMJgGFDNjANBgkqhkiG9w0BAQwFADBv
MQswCQYDVQQGEwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNVBAsTHUFk
ZFRydXN0IEV4dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRUcnVzdCBF
eHRlcm5hbCBDQSBSb290MB4XDTAwMDUzMDEwNDgzOFoXDTIwMDUzMDEwNDgzOFow
gYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtK
ZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYD
VQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MIICIjAN
BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAgBJlFzYOw9sIs9CsVw127c0n00yt
UINh4qogTQktZAnczomfzD2p7PbPwdzx07HWezcoEStH2jnGvDoZtF+mvX2do2NC
tnbyqTsrkfjib9DsFiCQCT7i6HTJGLSR1GJk23+jBvGIGGqQIjy8/hPwhxR79uQf
jtTkUcYRZ0YIUcuGFFQ/vDP+fmyc/xadGL1RjjWmp2bIcmfbIWax1Jt4A8BQOujM
8Ny8nkz+rwWWNR9XWrf/zvk9tyy29lTdyOcSOk2uTIq3XJq0tyA9yn8iNK5+O2hm
AUTnAU5GU5szYPeUvlM3kHND8zLDU+/bqv50TmnHa4xgk97Exwzf4TKuzJM7UXiV
Z4vuPVb+DNBpDxsP8yUmazNt925H+nND5X4OpWaxKXwyhGNVicQNwZNUMBkTrNN9
N6frXTpsNVzbQdcS2qlJC9/YgIoJk2KOtWbPJYjNhLixP6Q5D9kCnusSTJV882sF
qV4Wg8y4Z+LoE53MW4LTTLPtW//e5XOsIzstAL81VXQJSdhJWBp/kjbmUZIO8yZ9
HE0XvMnsQybQv0FfQKlERPSZ51eHnlAfV1SoPv10Yy+xUGUJ5lhCLkMaTLTwJUdZ
+gQek9QmRkpQgbLevni3/GcV4clXhB4PY9bpYrrWX1Uu6lzGKAgEJTm4Diup8kyX
HAc/DVL17e8vgg8CAwEAAaOB9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rEJlTv
A73gJMtUGjAdBgNVHQ4EFgQUU3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/
BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQGA1Ud
HwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVzdEV4
dGVybmFsQ0FSb290LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0
dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggEBAJNl9jeD
lQ9ew4IcH9Z35zyKwKoJ8OkLJvHgwmp1ocd5yblSYMgpEg7wrQPWCcR23+WmgZWn
RtqCV6mVksW2jwMibDN3wXsyF24HzloUQToFJBv2FAY7qCUkDrvMKnXduXBBP3zQ
YzYhBx9G/2CkkeFnvN4ffhkUyWNnkepnB2u0j4vAbkN9w6GAbLIevFOFfdyQoaS8
Le9Gclc1Bb+7RrtubTeZtv8jkpHGbkD4jylW6l/VXxRTrPBPYer3IsynVgviuDQf
Jtl7GQVoP7o81DgGotPmjw7jtHFtQELFhLRAlSv0ZaBIefYdgWOWnU914Ph85I6p
0fKtirOMxyHNwu8=
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

| Name                                      | Default                               | Example                                                                               | Description |
| ----------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------- | ----------- |
| service :exclamation:                     |                                       | "Vault Example"                                                                       | The service name. For Tech Services this would be the name in the Service Catalog. This is available as a tag on resources. |
| contact :exclamation:                     |                                       | "vault-example@illinois.edu"                                                          | Who to contact for problems. This is available as a tag on resources. |
| data_classification :exclamation:         |                                       | "Sensitive"                                                                           | The Illini Secure data classification. This should probably be "Sensitive" or "High Risk". This is available as a tag on storage resources. |
| environment                               | ""                                    | "Test"                                                                                | The environment: Development, Test, Staging, Production. Setting "Production" lengthens some of the retention periods of resources. This is available as a tag on resources. |
| project :exclamation:                     |                                       | "vault-exmp"                                                                          | Short, simple project name. Some resources have a "name" or "name prefix" and this will be used for that. |
| key_name :exclamation:                    |                                       | "Vault Example"                                                                       | Name of the EC2 Key Pair created earlier. |
| key_file :exclamation:                    |                                       | "~/.ssh/vault"                                                                        | Path to the SSH private key file on your local machine. |
| enhanced_monitoring                       | "0"                                   | "1"                                                                                   | Enable enhanced monitoring on EC2 instances created. |
| public_subnets :exclamation:              |                                       | \[ "techsvcsandbox-public1-a-net", "techsvcsandbox-public1-b-net" \]                  | List of names of public subnets. You should specify at least two for high availability. |
| deploy_bucket :exclamation:               |                                       | "deploy-vault.example.illinois.edu-us-east-2"                                         | Name of the bucket that contains the deployment resources (`server.key`, `server.crt`, `ldap-credentials.txt`). |
| deploy_prefix                             |                                       | "test/"                                                                               | Prefix of the resources inside the deployment bucket. This lets you use the same bucket for multiple deployments. If specified it must not begin with a "/" and must end with a "/". |
| vault_key_user_roles                      | \[\]                                  | \[ "TechServicesStaff" \]                                                             | List of IAM role names that are given access to the AWS KMS Custom Key protecting some of the resources. People with these roles will be able to read the master keys secret and the CloudWatch Logs. |
| vault_server_admin_groups :exclamation:   |                                       | \[ "Admin Group 1", "Admin Group 2" \]                                                | List AD group names that will be given full access to SSH to the EC2 instance and manage the Vault server. Only direct members of the group will be able to access all resources. |
| vault_server_private_ips :exclamation:    |                                       | \[ "10.224.255.51", "10.224.255.181" \]                                               | List of private IP addresses in the subnet. |
| vault_server_fqdn                         | ""                                    | "vault.example.illinois.edu"                                                          | Primary FQDN of the vault server, present in the SSL certificate as the CN. |
| vault_server_public_fqdns :exclamation:   |                                       | \[ "server-a.vault.example.illinois.edu", "server-b.vault.example.illinois.edu" \]    | List of the FQDN of the vault server EC2 instances. |
| vault_server_instance_type                | "t2.small"                            | "t2.medium"                                                                           | Instance type to use for the vault servers; do not use smaller than t2.micro. |
| vault_server_image                        | "vault:latest"                        | "vault:0.10.3"                                                                        | Docker image to use for the vault server. If you use the "latest" tag then each run of the terraform will make sure the image is the most current. Production might want to use a specific version tag. |
| vault_helper_image                        | "sbutler/uiuc-vault-helper:latest"    | "sbutler/uiuc-vault-helper:latest"                                                    | Docker image to use for the vault helper. If you use the "latest" tag then each run of the terraform will make sure the image is the most current. Production might want to use a specific version tag. |
| vault_storage_max_rcu                     | "20"                                  | "100"                                                                                 | Maximum number of Read Capacity Units for the DynamoDB table. |
| vault_storage_min_rcu                     | "5"                                   | "2"                                                                                   | Minimum number of Read Capacity Units for the DynamoDB table. Do not use a number smaller than 2. |
| vault_storage_max_wcu                     | "20"                                  | "100"                                                                                 | Maximum number of Write Capacity Units for the DynamoDB table. |
| vault_storage_min_wcu                     | "5"                                   | "2"                                                                                   | Minimum number of Write Capacity Units for the DynamoDB table. Do not use a number smaller than 2. |
| vault_storage_rcu_target                  | "70"                                  | "80"                                                                                  | Target percentage for autoscaling of the RCU. |
| vault_storage_wcu_target                  | "70"                                  | "80"                                                                                  | Target percentage for autoscaling of the WCU. |

Construct a file in `varfiles` with your variable choices. Using the
examples above, we might have a `varfiles/example.tfvars` that looks
like this:

```
service = "Vault Example"
contact = "vault-example@illinois.edu"
data_classification = "Sensitive"
environment = "Test"

project = "vault-exmp"
key_name = "Vault Example"
key_file = "~/.ssh/vault"
enhanced_monitoring = "1"
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
vault_server_instance_type = "t2.medium"
vault_server_image = "vault:latest"
vault_helper_image = "sbutler/uiuc-vault-helper:latest"

vault_storage_max_rcu = "100"
vault_storage_min_rcu = "2"
vault_storage_max_wcu = "100"
vault_storage_min_wcu = "2"
vault_storage_rcu_target = "80"
vault_storage_wcu_target = "80"
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
        key = "test/terraform/state"
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
