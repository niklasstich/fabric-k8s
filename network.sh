#!/bin/bash

OPTION=$1

install_operator() {

	echo "Creating Kind cluster...";
	kind create cluster --image=kindest/node:v1.22.2 --name fabric-ke --wait 60s --config=kind.yaml;

	echo "Install Operator using Helm";
	helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update ;
	helm install hlf-operator -f hlf-operator.yaml kfs/hlf-operator;

  echo "Waiting for Operator to be deployed"
	kubectl wait deployment/hlf-operator-controller-manager --for condition=available --timeout=60s;

	#ensure folders are created
	mkdir -p resources/orderer/ordererorg1
	mkdir -p resources/org1
	mkdir -p resources/org2
	mkdir -p resources/org3
}

create_CAs() {

	echo "Create Org1 CA";
	kubectl apply -f ./resources/org1/ca.yaml;

	echo "Create Org2 CA";
	kubectl apply -f ./resources/org2/ca.yaml;

	echo "Create Org3 CA";
	kubectl apply -f ./resources/org3/ca.yaml;

	echo "Create Orderer CA";
  kubectl apply -f ./resources/orderer/ordererorg1/ca.yaml

  sleep 2s;
	kubectl wait deployment/org1-ca --for condition=available --timeout=30s;
	kubectl wait deployment/org2-ca --for condition=available --timeout=30s;
	kubectl wait deployment/org3-ca --for condition=available --timeout=30s;
	kubectl wait deployment/ordererorg1-ca --for condition=available --timeout=30s;
	echo "Waiting 20 seconds for all CAs to start successfully";
	sleep 10s;
}

create_peers() {

	echo "Enroll peer in Org1 CA";
	kubectl hlf ca register --name=org1-ca --user=peer \
	  --secret=peerpw --type=peer \
	  --enroll-id enroll --enroll-secret=enrollpw \
	  --mspid Org1MSP;

  kubectl hlf peer create --storage-class=standard \
      --enroll-id=peer --mspid=Org1MSP \
      --enroll-pw=peerpw --capacity=5Gi \
      --name=org1-peer0 --ca-name=org1-ca.default \
      --output > resources/org1/peer1.yaml

	echo "Create Org1 peer";
	kubectl apply -f ./resources/org1/peer1.yaml;


	echo "Enroll peer in Org2 CA";
	kubectl hlf ca register --name=org2-ca --user=peer \
	  --secret=peerpw --type=peer \
	  --enroll-id enroll --enroll-secret=enrollpw \
	  --mspid Org2MSP;

  kubectl hlf peer create --storage-class=standard \
      --enroll-id=peer --mspid=Org2MSP \
      --enroll-pw=peerpw --capacity=5Gi \
      --name=org2-peer0 --ca-name=org2-ca.default \
      --output > resources/org2/peer1.yaml

	echo "Create Org2 peer";
	kubectl apply -f ./resources/org2/peer1.yaml;

	echo "Enroll peer in Org3 CA";
	kubectl hlf ca register --name=org3-ca --user=peer \
	  --secret=peerpw --type=peer \
	  --enroll-id enroll --enroll-secret=enrollpw \
	  --mspid Org3MSP;

  kubectl hlf peer create --storage-class=standard \
      --enroll-id=peer --mspid=Org3MSP \
      --enroll-pw=peerpw --capacity=5Gi \
      --name=org3-peer0 --ca-name=org3-ca.default \
      --output > resources/org3/peer1.yaml

	echo "Create Org3 peer";
	kubectl apply -f ./resources/org3/peer1.yaml;

	echo "Enroll peer in ordererorg1 CA";
  kubectl hlf ca register --name=ordererorg1-ca \
     --user=orderer --secret=ordererpw \
     --type=orderer --enroll-id enroll \
     --enroll-secret=enrollpw --mspid=OrdererMSP

  kubectl hlf ordnode create  --storage-class=standard \
     --enroll-id=orderer --mspid=OrdererMSP \
     --enroll-pw=ordererpw --capacity=2Gi \
     --name=ordnode-1 --ca-name=ordererorg1-ca.default \
     --output > resources/orderer/ordererorg1/orderer.yaml

}

create_orderingservice() {

  echo "Create ordering service"
  kubectl apply -f ./resources/orderer/ordererorg1/orderer.yaml

}

enrol_admins_on_peers() {
    echo "Create Org1 admin";
    kubectl hlf ca register --name=org1-ca --user=admin \
     --secret=adminpw --type=admin \
     --enroll-id enroll --enroll-secret=enrollpw \
     --mspid Org1MSP;

    echo "enroll to peer";
    kubectl hlf ca enroll --name=org1-ca \
     --user=admin --secret=adminpw --mspid Org1MSP \
     --ca-name ca  --output peer-org1.yaml

    echo "get network config";
    kubectl hlf inspect --output org1.yaml -o Org1MSP

    echo "add admin to network config";
    kubectl hlf utils adduser --userPath=peer-org1.yaml \
      --config=org1.yaml --username=admin --mspid=Org1MSP

    echo "Create Org2 admin and enroll to peer";
    kubectl hlf ca register --name=org2-ca --user=admin \
     --secret=adminpw --type=admin \
     --enroll-id enroll --enroll-secret=enrollpw \
     --mspid Org2MSP;

    echo "enroll to peer";
    kubectl hlf ca enroll --name=org2-ca \
     --user=admin --secret=adminpw --mspid Org2MSP \
     --ca-name ca  --output peer-org2.yaml

    echo "get network config";
    kubectl hlf inspect --output org2.yaml -o Org2MSP

    echo "add admin to network config";
    kubectl hlf utils adduser --userPath=peer-org2.yaml \
      --config=org2.yaml --username=admin --mspid=Org2MSP

    echo "Create Org3 admin and enroll to peer";
    kubectl hlf ca register --name=org3-ca --user=admin \
     --secret=adminpw --type=admin \
     --enroll-id enroll --enroll-secret=enrollpw \
     --mspid Org3MSP;

    echo "enroll to peer";
    kubectl hlf ca enroll --name=org3-ca \
     --user=admin --secret=adminpw --mspid Org3MSP \
     --ca-name ca  --output peer-org3.yaml

    echo "get network config";
    kubectl hlf inspect --output org3.yaml -o Org3MSP

    echo "add admin to network config";
    kubectl hlf utils adduser --userPath=peer-org3.yaml \
      --config=org3.yaml --username=admin --mspid=Org3MSP

    echo "wait for all peers to come online"
    sleep 10s;
  	kubectl wait deployment/org1-peer0 --for condition=available --timeout=30s;
    sleep 1s;
  	kubectl wait deployment/org2-peer0 --for condition=available --timeout=30s;
    sleep 1s;
  	kubectl wait deployment/org3-peer0 --for condition=available --timeout=30s;

}
#TODO: debug why this fails
create_channel() {
  echo "create network config with all MSPs"
  kubectl hlf inspect --output ordservice.yaml \
    -o OrdererMSP

  echo "register admin to ordererorg1 CA"
  kubectl hlf ca register --name=ordererorg1-ca \
     --user=admin --secret=adminpw \
     --type=admin --enroll-id enroll \
     --enroll-secret=enrollpw --mspid=OrdererMSP

  echo "enroll admin into ordererorg1 CA"
  kubectl hlf ca enroll --name=ordererorg1-ca \
    --user=admin --secret=adminpw --mspid OrdererMSP \
    --ca-name ca  --output admin-ordservice.yaml

  echo "Add admin to ordererorg1 network config"
  kubectl hlf utils adduser --userPath=admin-ordservice.yaml --config=ordservice.yaml --username=admin --mspid=OrdererMSP

  # enroll using the TLS CA
  echo "enroll with TLS CA"
  kubectl hlf ca enroll --name=ordererorg1-ca \
     --namespace=default --user=admin \
     --secret=adminpw --mspid OrdererMSP \
     --ca-name tlsca  \
     --output admin-tls-ordservice.yaml

  echo "wait 30s before we create channel so orderer can get up and running"
  sleep 30s

  echo "generate genesis block for channel demo with organizations 1,2,3 and orderer"
  kubectl hlf channel generate \
    --output=demo.block --name=demo \
    --organizations Org1MSP \
    --organizations Org2MSP \
    --organizations Org3MSP \
    --ordererOrganizations OrdererMSP

  echo "join orderernode into channel"
  kubectl hlf ordnode join --block=demo.block \
    --name=ordnode-1 --namespace=default \
    --identity=admin-tls-ordservice.yaml

  echo "second channel"
  kubectl hlf channel generate \
    --output=demo1.block --name=demo1 \
    --organizations Org1MSP \
    --organizations Org2MSP \
    --organizations Org3MSP \
    --ordererOrganizations OrdererMSP

  echo "join orderernode into second channel"
  kubectl hlf ordnode join --block=demo1.block \
    --name=ordnode-1 --namespace=default \
    --identity=admin-tls-ordservice.yaml

}
#TODO: commit chaincode into chain and test it from all peers
join_peers_into_channel() {
  echo "generate channel network configs"
  kubectl hlf inspect --output channel_cfg_org1.yaml -o Org1MSP -o Org2MSP -o Org3MSP -o OrdererMSP
  kubectl hlf inspect --output channel_cfg_org2.yaml -o Org1MSP -o Org2MSP -o Org3MSP -o OrdererMSP
  kubectl hlf inspect --output channel_cfg_org3.yaml -o Org1MSP -o Org2MSP -o Org3MSP -o OrdererMSP

  echo "insert users into config"
  kubectl hlf utils adduser --userPath=peer-org1.yaml --config=channel_cfg_org1.yaml --username=admin --mspid=Org1MSP
  kubectl hlf utils adduser --userPath=peer-org2.yaml --config=channel_cfg_org2.yaml --username=admin --mspid=Org2MSP
  kubectl hlf utils adduser --userPath=peer-org3.yaml --config=channel_cfg_org3.yaml --username=admin --mspid=Org3MSP

  echo "wait for 15 seconds while block creation propagates"
  sleep 15s

  echo "join peer into channels"
  kubectl hlf channel join --name=demo \
     --config=channel_cfg_org1.yaml \
     --user=admin -p=org1-peer0.default
  kubectl hlf channel join --name=demo \
     --config=channel_cfg_org2.yaml \
     --user=admin -p=org2-peer0.default
  kubectl hlf channel join --name=demo \
     --config=channel_cfg_org3.yaml \
     --user=admin -p=org3-peer0.default

  echo "make peer into anchorpeer"
  kubectl hlf channel addanchorpeer --channel=demo --config=channel_cfg_org1.yaml --user=admin --peer=org1-peer0.default;
  kubectl hlf channel addanchorpeer --channel=demo --config=channel_cfg_org2.yaml --user=admin --peer=org2-peer0.default;
  kubectl hlf channel addanchorpeer --channel=demo --config=channel_cfg_org3.yaml --user=admin --peer=org3-peer0.default;

  echo "join peer into second channels"
  kubectl hlf channel join --name=demo1 \
     --config=channel_cfg_org1.yaml \
     --user=admin -p=org1-peer0.default
  kubectl hlf channel join --name=demo1 \
     --config=channel_cfg_org2.yaml \
     --user=admin -p=org2-peer0.default
  kubectl hlf channel join --name=demo1 \
     --config=channel_cfg_org3.yaml \
     --user=admin -p=org3-peer0.default

  echo "make peer into anchorpeer in second channel"
  kubectl hlf channel addanchorpeer --channel=demo1 --config=channel_cfg_org1.yaml --user=admin --peer=org1-peer0.default;
  kubectl hlf channel addanchorpeer --channel=demo1 --config=channel_cfg_org2.yaml --user=admin --peer=org2-peer0.default;
  kubectl hlf channel addanchorpeer --channel=demo1 --config=channel_cfg_org3.yaml --user=admin --peer=org3-peer0.default;


}


push_chaincode_in_first_channel() {

  echo "installing chaincode on all nodes in parallel"
  parallel :::\
   'kubectl hlf chaincode install --path=./chaincodes/fabcar/go --config=channel_cfg_org1.yaml --language=golang --label=fabcar --user=admin --peer=org1-peer0.default' \
   'kubectl hlf chaincode install --path=./chaincodes/fabcar/go --config=channel_cfg_org2.yaml --language=golang --label=fabcar --user=admin --peer=org2-peer0.default' \
   'kubectl hlf chaincode install --path=./chaincodes/fabcar/go --config=channel_cfg_org3.yaml --language=golang --label=fabcar --user=admin --peer=org3-peer0.default'

  echo "parallel done!"

  echo "get installed chaincodes"
  kubectl hlf chaincode queryinstalled --config=channel_cfg_org1.yaml --user=admin --peer=org1-peer0.default
  kubectl hlf chaincode queryinstalled --config=channel_cfg_org2.yaml --user=admin --peer=org2-peer0.default
  kubectl hlf chaincode queryinstalled --config=channel_cfg_org3.yaml --user=admin --peer=org3-peer0.default

  echo "approve chaincodes"
  PACKAGE_ID=fabcar:0c616be7eebace4b3c2aa0890944875f695653dbf80bef7d95f3eed6667b5f40 # replace it with the package id of your
  echo "1"
  kubectl hlf chaincode approveformyorg --config=channel_cfg_org1.yaml --user=admin --peer=org1-peer0.default \
      --package-id=$PACKAGE_ID \
      --version "1.0" --sequence 1 --name=fabcar \
      --policy="AND('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" --channel=demo
  echo "2"
  kubectl hlf chaincode approveformyorg --config=channel_cfg_org2.yaml --user=admin --peer=org2-peer0.default \
      --package-id=$PACKAGE_ID \
      --version "1.0" --sequence 1 --name=fabcar \
      --policy="AND('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" --channel=demo
  echo "3"
  kubectl hlf chaincode approveformyorg --config=channel_cfg_org3.yaml --user=admin --peer=org3-peer0.default \
      --package-id=$PACKAGE_ID \
      --version "1.0" --sequence 1 --name=fabcar \
      --policy="AND('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" --channel=demo

  echo "wait until chaincode approval propagates"
  sleep 10s

  echo "commit chaincode (we only do that once)"
  kubectl hlf chaincode commit --config=channel_cfg_org1.yaml --mspid=Org1MSP --user=admin \
      --version "1.0" --sequence 1 --name=fabcar \
      --policy="AND('Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" --channel=demo

  echo "wait until chaincode commit propagates"
  sleep 5s

  echo "query"
  kubectl hlf chaincode query --config=channel_cfg_org1.yaml \
      --user=admin --peer=org1-peer0.default \
      --chaincode=fabcar --channel=demo \
      --fcn=QueryAllCars -a '[]'

  echo "call initLedger"
  kubectl hlf chaincode invoke --config=channel_cfg_org2.yaml \
      --user=admin --peer=org2-peer0.default \
      --chaincode=fabcar --channel=demo \
      --fcn=initLedger -a '[]'

  echo "query again"
  kubectl hlf chaincode query --config=channel_cfg_org3.yaml \
      --user=admin --peer=org3-peer0.default \
      --chaincode=fabcar --channel=demo \
      --fcn=QueryAllCars -a '[]'
}


echo "Arg: $OPTION";

if [ "$OPTION" == "up" ]
then
	install_operator;

	create_CAs;

	create_peers;

  create_orderingservice;

  enrol_admins_on_peers;

  create_channel;

  join_peers_into_channel;

  push_chaincode_in_first_channel;


elif  [ "$OPTION" == "down" ]
then
	echo "Tearing down Kind cluster...";
	kind delete cluster --name fabric-ke;
fi