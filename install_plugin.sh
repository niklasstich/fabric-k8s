wget "https://github.com/kfsoftware/hlf-operator/releases/download/v1.4.0-beta4/hlf-operator_1.4.0-beta4_linux_amd64.zip"
rm -rf ./hlf-operator
unzip hlf-operator_1.4.0-beta4_linux_amd64.zip -d hlf-operator
chmod +x ./hlf-operator/kubectl-hlf
sudo mv ./hlf-operator/kubectl-hlf /usr/local/bin/kubectl-hlf

