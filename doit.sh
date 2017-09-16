#!/bin/bash
## install aws cli
echo "Indstalling AWS CLI, please stand-by..."
curl -O https://bootstrap.pypa.io/get-pip.py >/dev/null
sudo python get-pip.py --user >/dev/null
~/.local/bin/pip install awscli --upgrade --user >/dev/null
sudo /bin/cp -rf ~/.local/bin/* /usr/bin >/dev/null
echo ""
echo ""
echo ""
echo " Please Enter youw AWS Access Key ID, Secret Key and Region "
echo ""
aws configure

echo "***********************************************************************"
echo "*                                                                     *"
echo "*            OK - Let's Start - this will take cca 30 min.!           *"
echo "*                                                created by: bgonev   *"
echo "***********************************************************************"

## Definitions

vpc_cidr='192.168.0.0/16'
z1='ca-central-1a'
z2='ca-central-1b'
z1_pub_cidr='192.168.101.0/24'
z1_pvt_cidr='192.168.1.0/24'
z2_pub_cidr='192.168.201.0/24'
z2_pvt_cidr='192.168.2.0/24'
inst_type='t2.medium'
image='ami-daeb57be'

## Create directories for files generated by this script
mkdir -p ./to_aws/files
mkdir -p ./to_aws/keys

## Function for taging the objects
tag () {
aws ec2 create-tags --resources $1 --tags Key=Owner,Value=bgonev
}

## Create VPC infrastructure

echo "Creating VPC objects..."

vpc_id=`aws ec2 create-vpc --cidr-block $vpc_cidr --query Vpc.VpcId --output text`
aws ec2 create-tags --resources $vpc_id --tags Key=Owner,Value=bgonev
sub1_pub_id=`aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $z1_pub_cidr --availability-zone $z1 --query Subnet.SubnetId --output text`
sub2_pub_id=`aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $z2_pub_cidr --availability-zone $z2 --query Subnet.SubnetId --output text`
sub1_pvt_id=`aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $z1_pvt_cidr --availability-zone $z1 --query Subnet.SubnetId --output text`
sub2_pvt_id=`aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $z2_pvt_cidr --availability-zone $z2 --query Subnet.SubnetId --output text`
gw_id=`aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text`
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $gw_id >/dev/null
rt_id=`aws ec2 create-route-table --vpc-id $vpc_id --query RouteTable.RouteTableId --output text`
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id  $gw_id --output text >/dev/null
aws ec2 associate-route-table  --subnet-id $sub1_pub_id --route-table-id $rt_id --output text >/dev/null
aws ec2 associate-route-table  --subnet-id $sub2_pub_id --route-table-id $rt_id --output text >/dev/null
aws ec2 modify-subnet-attribute --subnet-id $sub1_pub_id --map-public-ip-on-launch >/dev/null
aws ec2 modify-subnet-attribute --subnet-id $sub2_pub_id --map-public-ip-on-launch >/dev/null
eip_id=`aws ec2 allocate-address --domain vpc --query AllocationId --output text`
natgw_id=`aws ec2 create-nat-gateway --subnet-id $sub1_pub_id --allocation-id $eip_id --query NatGateway.NatGatewayId --output text`
## We must sleep here as on tests Pending message was > 60 < seconds
sleep 120
main_rt_id=`aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main == \`true\`]' --output text | head -1 | awk '{print $1}'`
aws ec2 create-route --route-table-id $main_rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $natgw_id --output text >/dev/null
objects=("$vpc_id" "$sub1_pub_id" "$sub1_pub_id" "$sub1_pub_id" "$sub1_pub_id" "$gw_id" "$rt_id" "$natgw_id" "$natgw_id")

## Tag VPC objects

echo "---------VPC Objects--------" >> /tmp/aws_objects.log
for object in "${objects[@]}"
do
tag $object
echo $object >> /tmp/aws_objects.log
done

## Create Security Groups

puppet_sg=`aws ec2 create-security-group --group-name puppet-sec-group --description "puppet security group " --vpc-id $vpc_id --query 'GroupId' --output text`
web_sg=`aws ec2 create-security-group --group-name web-sec-group --description "Web servers security group" --vpc-id $vpc_id --query 'GroupId' --output text`
nfs_sg=`aws ec2 create-security-group --group-name nfs-sec-group --description "NFS serverst security group " --vpc-id $vpc_id --query 'GroupId' --output text`
sql_sg=`aws ec2 create-security-group --group-name sql-sec-group --description "SQL serverst security group " --vpc-id $vpc_id --query 'GroupId' --output text`
lb_sg=`aws ec2 create-security-group --group-name lb-sec-group --description "LB security group " --vpc-id $vpc_id --query 'GroupId' --output text`

## Tag SG and enable unrestricted local communication on 

sg_list=("$puppet_sg" "$web_sg" "$nfs_sg" "$sql_sg")
echo "---------SG Objects--------" >> /tmp/aws_objects.log
for sg in "${sg_list[@]}"
do
tag $sg
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $sg --protocol tcp --port 1-65535 --cidr $vpc_cidr >/dev/null
aws ec2 authorize-security-group-ingress --group-id $sg --protocol udp --port 1-65535 --cidr $vpc_cidr >/dev/null
aws ec2 authorize-security-group-ingress --group-id $sg --ip-permissions '[{"IpProtocol": "icmp", "FromPort": 8, "ToPort": 0, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' >/dev/null
echo $sg >> /tmp/aws_objects.log
done

## Additional configuration of SG
aws ec2 authorize-security-group-ingress --group-id $web_sg --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $web_sg --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $lb_sg --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null
aws ec2 authorize-security-group-ingress --group-id $lb_sg --protocol tcp --port 443 --cidr 0.0.0.0/0 >/dev/null

## Create PEM key files

echo "Creating PEM key files in ./keys ..."

## Create PEM keys
cmd_key_pair () {
aws ec2 create-key-pair --key-name $1 --query 'KeyMaterial' --output text > ./to_aws/keys/$1.pem
}
cmd_key_pair puppet
cmd_key_pair web1
cmd_key_pair web2
cmd_key_pair nfsserver1
cmd_key_pair nfsserver2
cmd_key_pair sql1
cmd_key_pair sql2

## Create Machines

echo "Creating $inst_type instances..."

puppet_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name puppet --security-group-ids $puppet_sg --subnet-id $sub1_pub_id --associate-public-ip-address --query 'Instances[0].InstanceId' --output text`
web1_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name web1 --security-group-ids $web_sg --subnet-id $sub1_pub_id --associate-public-ip-address --query 'Instances[0].InstanceId' --output text`
web2_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name web2 --security-group-ids $web_sg --subnet-id $sub2_pub_id --associate-public-ip-address --query 'Instances[0].InstanceId' --output text`
nfs1_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name nfsserver1 --security-group-ids $nfs_sg --subnet-id $sub1_pvt_id --query 'Instances[0].InstanceId' --output text`
nfs2_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name nfsserver2 --security-group-ids $nfs_sg --subnet-id $sub2_pvt_id --query 'Instances[0].InstanceId' --output text`
sql1_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name sql1 --security-group-ids $sql_sg --subnet-id $sub1_pvt_id --query 'Instances[0].InstanceId' --output text`
sql2_id=`aws ec2 run-instances --image-id $image --count 1 --instance-type $inst_type --key-name sql2 --security-group-ids $sql_sg --subnet-id $sub2_pvt_id --query 'Instances[0].InstanceId' --output text`

t2_list=("$puppet_id" "$web1_id" "$web2_id" "$nfs1_id" "$nfs2_id" "$sql1_id" "$sql2_id")
echo "---------t2.micro Objects--------" >> /tmp/aws_objects.log
for t2 in "${t2_list[@]}"
do
tag $t2
echo $t2 >> /tmp/aws_objects.log
done

## Sleep and wait all instances to be up and running
echo " Waiting 30 seconds for all machines to be Running..." 
sleep 30

## Create Application load Balancer
lb_arn=`aws elbv2 create-load-balancer --name lbbgonev  --subnets $sub1_pub_id $sub2_pub_id --security-groups $lb_sg --query 'LoadBalancers[0].LoadBalancerArn' --output text`
tg80_arn=`aws elbv2 create-target-group --name web80srvrsc8 --protocol HTTP --port 80 --vpc-id $vpc_id --query 'TargetGroups[0].TargetGroupArn' --output text`
tg443_arn=`aws elbv2 create-target-group --name web443srvrsc8 --protocol HTTPS --port 443 --vpc-id $vpc_id --query 'TargetGroups[0].TargetGroupArn' --output text`
aws elbv2 register-targets --target-group-arn $tg80_arn --targets Id=$web1_id Id=$web2_id >/dev/null
sleep 2
aws elbv2 register-targets --target-group-arn $tg80_arn --targets Id=$web1_id Id=$web2_id >/dev/null
aws elbv2 register-targets --target-group-arn $tg443_arn --targets Id=$web1_id Id=$web2_id >/dev/null
aws elbv2 create-listener --load-balancer-arn $lb_arn --protocol HTTP --port 80  --default-actions Type=forward,TargetGroupArn=$tg80_arn >/dev/null
aws elbv2 create-listener --load-balancer-arn $lb_arn --protocol HTTPS --port 443  --certificates CertificateArn=arn:aws:iam::272462672480:server-certificate/aws-demo --default-actions Type=forward,TargetGroupArn=$tg443_arn >/dev/null
lb_address=`aws elbv2 describe-load-balancers --names lbbgonev --query LoadBalancers[0].DNSName --output text`

## Create folumes for NFS
## Here we are waiting for 1 min t2.micro to be in running state
echo "Create volumes for NFS cluster..."
vol1_id=`aws ec2 create-volume --size 10 --availability-zone $z1 --volume-type gp2 --query VolumeId --output text`
vol2_id=`aws ec2 create-volume --size 10 --availability-zone $z2 --volume-type gp2 --query VolumeId --output text`
echo "Waiting volumes to became ready..." 
sleep 30
aws ec2 attach-volume --volume-id $vol1_id --instance-id $nfs1_id --device /dev/sdf --output text
aws ec2 attach-volume --volume-id $vol2_id --instance-id $nfs2_id --device /dev/sdf --output text


## Find Public and Private addresses for each instance 

## Public IPs
puppet_pub_ip=`aws ec2 describe-instances --instance-ids $puppet_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text`
web1_pub_ip=`aws ec2 describe-instances --instance-ids $web1_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text`
web2_pub_ip=`aws ec2 describe-instances --instance-ids $web2_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text`

## Private IPs
puppet_pvt_ip=`aws ec2 describe-instances --instance-ids $puppet_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
web1_pvt_ip=`aws ec2 describe-instances --instance-ids $web1_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
web2_pvt_ip=`aws ec2 describe-instances --instance-ids $web2_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
nfs1_pvt_ip=`aws ec2 describe-instances --instance-ids $nfs1_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
nfs2_pvt_ip=`aws ec2 describe-instances --instance-ids $nfs2_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
sql1_pvt_ip=`aws ec2 describe-instances --instance-ids $sql1_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
sql2_pvt_ip=`aws ec2 describe-instances --instance-ids $sql2_id --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text`
sleep 30
lb_ip=`dig +short $lb_address | head -1`
echo "Following are IP addresses: "
echo "Puppet public IP : " $puppet_pub_ip
echo "Puppet private IP: " $puppet_pvt_ip
echo "Web1 public IP   : " $web1_pub_ip
echo "Web1 private IP  : " $web1_pvt_ip
echo "Web2 public IP   : " $web2_pub_ip
echo "Web2 private IP  : " $web2_pvt_ip
echo "Nfs1 private IP  : " $nfs1_pvt_ip
echo "Nfs2 private IP  : " $nfs2_pvt_ip
echo "Sql1 private IP  : " $sql1_pvt_ip
echo "Sql2 private IP  : " $sql2_pvt_ip
echo "LB Pubblic Addr  : " $lb_ip
echo "LB Address       : " $lb_address

## Following goes to the log file 

echo "-------Following are IP addresses-------" >> /tmp/aws_objects.log 
echo "Puppet public IP : " $puppet_pub_ip >> /tmp/aws_objects.log
echo "Puppet private IP: " $puppet_pvt_ip >> /tmp/aws_objects.log
echo "Web1 public IP   : " $web1_pub_ip >> /tmp/aws_objects.log
echo "Web1 private IP  : " $web1_pvt_ip >> /tmp/aws_objects.log
echo "Web2 public IP   : " $web2_pub_ip >> /tmp/aws_objects.log
echo "Web2 private IP  : " $web2_pvt_ip >> /tmp/aws_objects.log
echo "Nfs1 private IP  : " $nfs1_pvt_ip >> /tmp/aws_objects.log
echo "Nfs2 private IP  : " $nfs2_pvt_ip >> /tmp/aws_objects.log
echo "Sql1 private IP  : " $sql1_pvt_ip >> /tmp/aws_objects.log
echo "Sql2 private IP  : " $sql2_pvt_ip >> /tmp/aws_objects.log
echo "LB Pubblic Addr  : " $lb_ip >> /tmp/aws_objects.log
echo "LB Pubblic Addr  : " $lb_address >> /tmp/aws_objects.log

## create hosts file for environment

echo $puppet_pvt_ip " puppet puppet.domain.com" >> ./to_aws/files/hosts
echo $web1_pvt_ip " web1 web1.domain.com" >> ./to_aws/files/hosts
echo $web2_pvt_ip " web2 web2.domain.com" >> ./to_aws/files/hosts
echo $nfs1_pvt_ip " nfsserver1 nfsserver1.domain.com" >> ./to_aws/files/hosts
echo $nfs2_pvt_ip " nfsserver2 nfsserver2.domain.com" >> ./to_aws/files/hosts
echo $sql1_pvt_ip " sql1 sql1.domain.com" >> ./to_aws/files/hosts
echo $sql2_pvt_ip " sql2 sql2.domain.com" >> ./to_aws/files/hosts
echo "LB Pubblic Addr  : " $lb_ip >> ./to_aws/files/lb.ip
echo "LB Addr  : " $lb_address >> ./to_aws/files/lb.address

## Start working on Puppet server
chmod -R 400 ./to_aws/keys
exe_pup() {
ssh -i ./to_aws/keys/puppet.pem -o StrictHostKeyChecking=no centos@$puppet_pub_ip $1
}

cp_pup() {
scp -i ./to_aws/keys/puppet.pem -o StrictHostKeyChecking=no $1 centos@$puppet_pub_ip:$2
}
exe_pup "rm -rf ~/tmp/from_git"
exe_pup "mkdir -p ./tmp/to_aws/keys"
exe_pup "mkdir -p ./tmp/to_aws/files"
cp_pup "./to_aws/keys/*" "~/tmp/to_aws/keys/"
cp_pup "./to_aws/files/*" "~/tmp/to_aws/files/"
cp_pup "/tmp/aws_objects.log" "~/tmp/to_aws/files/"
exe_pup "sudo hostnamectl set-hostname puppet.domain.com"
exe_pup "sudo yum -y install git"
exe_pup "git clone https://github.com/bgonev/dalia.git ~/tmp/from_git"

## Temporary enable root trough ssh

ssh -i ./to_aws/keys/puppet.pem centos@$puppet_pub_ip "sudo -i cp -rf /root/.ssh/authorized_keys /root/.ssh/authorized_keys_orig"
ssh -i ./to_aws/keys/puppet.pem centos@$puppet_pub_ip "sudo -i cp -rf ~/.ssh/authorized_keys /root/.ssh/authorized_keys"

## Add hosts to hosts file

cat ./to_aws/files/hosts | ssh -i ./to_aws/keys/puppet.pem root@$puppet_pub_ip "cat >> /etc/hosts"

## Disable root ssh access

ssh -i ./to_aws/keys/puppet.pem root@$puppet_pub_ip "sudo -i cp -rf /root/.ssh/authorized_keys_orig /root/.ssh/authorized_keys"

## call run script on puppet

ssh -i ./to_aws/keys/puppet.pem centos@$puppet_pub_ip "~/tmp/from_git/files/run_on_puppet.sh"

ssh -i ./to_aws/keys/puppet.pem centos@$puppet_pub_ip "~/tmp/from_git/files/end.sh"
