Created a Terraform module with Ec2 instances configures with AWS ALB and the instances will be serving a webpage which will display "Hello world" with the current date and time.

# configurations
-> 1. create vpc
-> 2. create Internet Gateway
-> 3.creating 2 subnets in different region
-> 4. create custom routing table
-> 5. Associate subnet with routing table
-> 6. create security group to allow web traffic
-> 7. create Launch configuration for web servers
-> 8. create Load balncer for web servers
-> 9. creating Auto Scaling Group

# Additional configurations made
-> alarams configured for email notifications with SNS based on cpu utilization(server usage)
-> creating sns topic and email subscription to monitor healthy targets through load balancer

# instructions to create the infrastructure
  
  # pre requisites
  -> aws cli need to  be installed locally and configured with AWS_ACCESS_KEY, AWS_SECRET_KEY and region (N.virginia) on the local system to run the module with out any errors.

# instructions
-> navigate to variable.tf file 
   1. Provide your AWS_ACCESS_KEY
   2. Provide your AWS_SECRET_KEY
   3. add your keypair to access the ec2-instances

we have configured cloud watch alarams and created SNS topics and subscriptions with email
   4. in variable.tf file add your email to get the notifications on server usage and instance health 

# execution
-> After the changes are made in the variable.tf  Please apply the following comands

terraform init    (it will download AWS Plugins required to create the infrasructure)
terraform plan    (terraform will plan and show the infra details before making any actual changes)
terraform apply   ( After verifying all the details in terraform apply will create the infrastructure )

# Note:after the module is executed you will be getting a subscription email from AWS you have to approve it in order  to get the cloudwatch notifications.

# output
-> after the infra is created get the dns name from the outputs and try it in your browser
   -> it should display the current date and time
   
-> we have created the cloud watch metrics for server usage and load balancer healthchecks
  
  # metrics conditions
  1. CPUUtilization >= 50 for 4 minutes   Then   websever_scaleup_alaram will trigger 
  2. CPUUtilization <= 20 for 4 minutes   Then   websever_scaledown_alaram will trigger
  3. if the target is not healthy         Then   load_balancer_healthcheck_alaram will trigger

# For every Alaram got triggered you will be getting an email notification from AWS
