# GCP

1. Log in first
```
gcloud auth application-default login
```
2. Create a file called terraforms.tfvars and add the following variables
```
zip_file_id = ""
ams_version = ""

```
3. Generate a new SSH key
```
mkdir ./ssh
ssh-keygen -t rsa -f ./ssh/id_rsa
```
# DO

1. First create a DO token

2. Create a file called terraforms.tfvars and add the following variables

```
zip_file_id = ""
do_token = ""
ams_version = ""
```
3. Generate a new SSH key
```
mkdir ./ssh
ssh-keygen -t rsa -f ./ssh/id_rsa
```

## Make sure everything works properly
```
terraform plan
```
## Install the deployments
```
terraform apply -auto-approve
```
