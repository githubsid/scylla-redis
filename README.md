# scylla-redis
Script/Documentation to evaluate ScyllaDB's Redis support


#### Notes on running AWS ElastiCache and ScyllaDB on AWS

```
#
# Memtier Prep
#
sudo yum group install -y "Development Tools"
sudo yum install -y autoconf automake make gcc-c++ 
sudo yum install -y pcre-devel zlib-devel libmemcached-devel
yum install -y wget

sudo yum install -y openssl-devel openssl-static
sudo yum install -y libevent-devel

aws ec2 run-instances --block-device-mappings DeviceName=/dev/sda1,Ebs={VolumeSize=100} --key-name sid_scylla --image-id ami-a0cfeed8 --instance-type c5.9xlarge --instance-initiated-shutdown-behavior terminate --placement AvailabilityZone="us-west-2c"

# Increase the number of open file descriptors /etc/security/limits.conf
# <domain> <type> <item>  <value>
    *       soft  nofile  100000
    *       hard  nofile  100000

#
# Scylla Prep
#
sudo yum install -y vim git
sudo yum install -y docker
sudo systemctl start docker
sudo groupadd docker
sudo usermod -aG docker `whoami`
echo "Logout and login"
sudo systemctl restart docker
echo "Run `docker run hello-world` to see if it works"
yum install centos-release-scl
yum install devtoolset-8-gcc devtoolset-8-gcc-c++


#
# Build Scylla on CentOS 7
#

scl enable devtoolset-8 bash
git clone https://github.com/scylladb/scylla
cd scylla
git submodule update --init --recursive
sudo ./install-dependencies.sh
screen
./tools/toolchain/dbuild ./reloc/build_reloc.sh --mode release
./tools/toolchain/dbuild ./reloc/build_rpm.sh --reloc-pkg build/release/scylla-package.tar.gz
./tools/toolchain/dbuild ./reloc/python3/build_reloc.sh
./tools/toolchain/dbuild ./reloc/python3/build_rpm.sh                       

cd build/redhat/RPMS/x86_64/
ls -ltr
sudo rpm -ivh scylla-python3-3.7.6-0.20200220.4e95b6750.x86_64.rpm
sudo rpm -ivh scylla-conf-666.development-0.20200220.4e95b6750.x86_64.rpm
sudo rpm -ivh scylla-server-666.development-0.20200220.4e95b6750.x86_64.rpm
scylla --version


# Scylla AMI
aws ec2 run-instances --block-device-mappings DeviceName=/dev/sda1,Ebs={VolumeSize=100} --key-name sid_scylla --image-id ami-06c367fd2288be149 --instance-type i3.8xlarge --instance-initiated-shutdown-behavior terminate --placement AvailabilityZone="us-west-2a"

# Scylla AMI Setup
sudo systemctl status scylla-ami-setup
sudo systemctl status scylla-server
set redis_port parameter in /etc/scylla/scylla.yaml, restart scylla-server
sudo yum install epel-release -y
sudo yum install redis -y
echo 'redis_port: 7001' | sudo tee --append /etc/scylla/scylla.yaml
sudo systemctl restart scylla-server

# Cleanup 
sudo rm -rf /var/lib/scylla/data
sudo find /var/lib/scylla/commitlog -type f -delete
sudo find /var/lib/scylla/hints -type f -delete
sudo find /var/lib/scylla/view_hints -type f -delete

CentOS ami ami-a042f4d8

aws ec2 run-instances --block-device-mappings DeviceName=/dev/sda1,Ebs={VolumeSize=100} --key-name sid_scylla --image-id ami-a042f4d8 --instance-type i3.large --instance-initiated-shutdown-behavior terminate


#
# Compiling Redis
#
http://download.redis.io/releases/redis-5.0.7.tar.gz
git clone redis or get the latest from web site
scl enable ... 
make
./src/redis-server --protected-mode no

sysctl -w fs.file-max=200000
vi /etc/sysctl.conf
fs.file-max=500000
sysctl -p


#
# Elastic Cache
#
aws elasticache create-cache-cluster --cache-cluster-id sid-ec --az-mode single-az --num-cache-nodes 1 --cache-node-type cache.r5.24xlarge --preferred-availability-zones us-west-2c --engine redis --dry-run

# Find endpoint
aws elasticache describe-cache-clusters --cache-cluster-id sid-ec --show-cache-node-info

# Delete
aws elasticache delete-cache-cluster --cache-cluster-id sid-ec

# Elastic Cache Replication Group
aws elasticache create-replication-group \
    --replication-group-id "sid-ec-rgroup" \
    --replication-group-description "Sid EC 1TB" \
    --engine "redis" \
    --cache-node-type "cache.r4.8xlarge" \
    --num-node-groups 8 \
    --replicas-per-node-group 1 \
    --automatic-failover-enabled

aws elasticache delete-replication-group --replication-group-id "sid-ec-rgroup"

# Scylla
/bin/scylla --options-file ./conf/scylla.yaml --redis-port 7001 --workdir /mnt/nvme -c 32 --developer-mode 1
/bin/scylla --options-file /etc/scylla/scylla.yaml --redis-port 7001 --workdir /mnt/nvme -c 32 --io-properties-file /etc/scylla.d/io_properties.yaml
```
