#!/usr/bin/env bash
#
# this will deploy bootstrapper and setup port-forward in the remote container,
# When the remote container starts, bootstrapper will be run under the golang debugger "dlv"
# and wait for a connection which can be done using goland's remote go configuration.
# See the [developer_guide.md](./developer_guide.md) for additional details.
#

usage() {
  echo "usage: $0 <image> <port>"
  exit 0
}

cleanup() {
  if [[ -n $pid ]]; then
    echo killing $pid
    kill -9 $pid
  fi
}
trap cleanup EXIT

portforward() {
  local pod=$1 namespace=$2 from_port=$3 to_port=$4 cmd
  kubectl port-forward $pod ${from_port}:${to_port} --namespace=$namespace 2>&1>/dev/null &
  pid=$!
  echo 'pid='$pid
}

waitforpod() {
  local cmd="kubectl get pods --no-headers -oname --selector=app=kubeflow-bootstrapper --field-selector=status.phase=Running --namespace=kubeflow-admin | sed 's/^pod.*\///'" found=$(eval "$cmd")
  while [[ -z $found ]]; do
    sleep 1
    found=$(eval "$cmd")
  done
  echo $found
}

pid=''
image=$1
port=$2
token=$3
command=$4
args="$5"
namespace=kubeflow-admin
echo "Waiting for pod's status == Running ..."
pod=$(waitforpod)
echo "Pod $pod is running. Setting up port-forward"
portforward $pod $namespace $port $port
echo $image --url="http://localhost:$port" --token="$token" $command $args
$image --url="http://localhost:$port" --token="$token" $command $args
echo "Type Ctrl^C to end to interrupt"
