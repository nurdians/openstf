#!/usr/bin/env bash
#######################################################################################
# file:    deploy_stf.sh
# brief:   deploy components of stf with docker
# creator: thinkhy
# date:    2017-04-20
# usage:   ./deploy_stf.sh  Note: run it as ROOT user
# changes: 
#    1. 2017-04-20 init  @thinkhy
#    2. 2017-04-26 add systemd unit  @thinkhy
#    3. 2017-05-04 install adb on host machine @thinkhy
#    4. 2017-07-22 generate and customize nginx.conf
# 
#######################################################################################

NETNAME=""
NETWORK_INTERFACES=$(ls /sys/class/net)

DNS_ADDRESS=$(nmcli device show ${NETNAME}|grep "IP4\.DNS\[1\]"|awk '{print $2}')
echo "DNS Address: ${DNS_ADDRESS}"

# Get exported IP Adreess 
[ ! -z "$(echo ${NETWORK_INTERFACES} | grep "wlo1")" ]&&NETNAME="wlo1"
[ ! -z "$(echo ${NETWORK_INTERFACES} | grep "eno1")" ]&&NETNAME="eno1"
IP_ADDRESS=192.168.56.102
echo "IP ADDRESS: ${IP_ADDRESS}"

check_return_code() {
  if [ $? -ne 0 ]; then
    echo "Failed to run last step!"     
    return 1
  fi
   
  return 0
}

assert_run_ok() {
  if [ $? -ne 0 ]; then
    echo "Failed to run last step!"     
    exit 1
  fi
   
  return 0
}

prepare() {
  echo "setup environment ..."

  # Given advantages of performance and stability, we run adb server and rethinkdb 
  # on host(physical) machine rather than on docker containers, so need to
  #  install package of android-tools-adb first [ thinkhy 2017-05-04 ]

  # install adb
  apt-get install -y android-tools-adb

  apt-get install -y docker.io
  assert_run_ok

  docker pull openstf/stf 
  assert_run_ok

  #docker pull sorccu/adb 
  #assert_run_ok

  docker pull rethinkdb 
  assert_run_ok

  docker pull openstf/ambassador 
  assert_run_ok

  cp -rf adbd.service.template /etc/systemd/system/adbd.service  
  assert_run_ok

  sed -e "s/__IP_ADDRESS__/${IP_ADDRESS}/g"                     \
      -e "s/__DNS_ADDRESS__/${DNS_ADDRESS}/g"	                \
    nginx.conf.template |tee nginx.conf 
  echo 1>"env.ok"

}

if [ ! -e env.ok ]; then
  prepare
fi

# start local adb server
echo "start adb server"
systemctl start adb

# provider
echo "start docker container: provider-${HOSTNAME}"
docker rm -f provider2
docker run -d --name provider2 --net host openstf/stf stf provider --name "provider-${HOSTNAME}" --connect-sub tcp://${IP_ADDRESS}:7250 --connect-push tcp://${IP_ADDRESS}:7270 --storage-url http://192.168.56.102 --public-ip ${IP_ADDRESS} --min-port=15000 --max-port=25000 --heartbeat-interval 20000 --screen-ws-url-pattern "ws://192.168.56.102/d/floor5/<%= serial %>/<%= publicPort %>/"
check_return_code


