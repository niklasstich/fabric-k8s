OPTION=$1

echo "Arg: $OPTION";

if [ "$OPTION" == "up" ]
then
	echo "Creating Kind cluster...";
	kind create cluster --image=kindest/node:v1.22.2 --name fabric-ke;

	echo "Install Operator using Helm";
	helm repo add kfs https://kfsoftware.github.io/hlf-helm-charts --force-update ;
	helm install hlf-operator -f hlf-operator.yaml kfs/hlf-operator;

	kubectl wait deployment/hlf-operator-controller-manager --for condition=available --timeout=30s;
	
	echo "Create Org1 CA";
	kubectl apply -f ./resources/org1/ca.yaml;
	sleep 1s;

	kubectl wait deployment/org1-ca --for condition=available --timeout=30s;
	echo "Waiting 15 seconds for all CAs to start successfully";
	sleep 15s;
	
	echo "Enroll peer in Org1 CA";
	kubectl hlf ca register --name=org1-ca --user=peer \
	  --secret=peerpw --type=peer \
	  --enroll-id enroll --enroll-secret=enrollpw \
	  --mspid Org1MSP;
	
	echo "Create Org1 peer";
	kubectl apply -f ./resources/org1/peer1.yaml;

  echo "Create Org1 admin and enroll to peer";
  kubectl hlf ca register --name=org1-ca --user=admin \
   --secret=adminpw --type=admin \
   --enroll-id enroll --enroll-secret=enrollpw \
   --mspid Org1MSP;

elif  [ "$OPTION" == "down" ]
then
	echo "Tearing down Kind cluster...";
	kind delete cluster --name fabric-ke;
fi