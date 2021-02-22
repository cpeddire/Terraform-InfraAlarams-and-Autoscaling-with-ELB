# Please provide the accesskey and secret key values 

variable "AWS_ACCESS_KEY"{
        description = "My AWS Accesskey"
        default = "<Provide AccessKey>"
        }
        
variable "AWS_SECRET_KEY"{
        description = "My AWS Secretkey"
        default = "<Provide SecretKey"
        }

variable "AWS_REGION"{
        description = "Default Region"
        default = "us-east-1"
        }

# Please create a keypair or if you have a keypair already then enter the keypair details below to access the ec2 instances

variable "keypair"{
        description = "AWS Keypair"
        default = "<Provide Keypair>"
        }




# we have configured Cloud Watch alarams with AWS SNS for Loadbalaner and EC2 montoring as well Please Provide your email below

variable "protocol" {
    description = "The protocol you want to use."
    default = "email"
}

variable "notification_endpoint" {
    description = "The notification-endpoint that you want to receive notifications."
	default = "xxxxx@gmail.com"
}