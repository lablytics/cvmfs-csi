function install_cvmfs(){
    echo "Installing CVMFS on K8s..."
    git clone https://github.com/lablytics/cvmfs-csi /home/ubuntu/cvmfs-csi
    microk8s helm3 install cvmfs /home/ubuntu/cvmfs-csi/deployments/helm/cvmfs-csi -n kube-system -f /home/ubuntu/cvmfs-values.yaml
    echo "CVMFS installed successfully"
    sleep 120
}

function install_galaxy(){
    echo "Installing Galaxy on K8s..."
    microk8s kubectl create namespace galaxy
    microk8s kubectl apply -f /home/ubuntu/galaxy-pvc.yaml 
    echo "Sleeping for 15 seconds..."
    sleep 15
    echo "Waking up..."
    # Install Galaxy dependencies -> This is new and does not work out of the box as the authors of Galaxy expected. There needs to better documentation on how to install Galaxy on Kubernetes.
    # git clone https://github.com/galaxyproject/galaxy-helm-deps.git /home/ubuntu/galaxy-helm-deps
    # cd /home/ubuntu/galaxy-helm-deps/galaxy-deps
    # sudo helm dependency build
    # helm install -n kube-system galaxy-project /home/ubuntu/galaxy-helm-deps/galaxy-deps --set cvmfs.storageClassName=cvmfs #--set cvmfs.deploy=false

    # Install Galaxy
    git clone https://github.com/galaxyproject/galaxy-helm.git /home/ubuntu/galaxy-helm
    cd /home/ubuntu/galaxy-helm/galaxy
    git checkout 2557baac75ee56c8c9801946c9ee8d633db7d56e # Checkout to the version that works with the current Galaxy version
    sudo microk8s helm3 dependency update
    microk8s helm3 install -n galaxy galaxy-project /home/ubuntu/galaxy-helm/galaxy -f /home/ubuntu/galaxy-values.yaml --timeout 1m30s
    echo "Galaxy installed successfully"
}

function main(){
    install_cvmfs
    # sleep for 30 seconds
    echo "Sleeping for 30 seconds..."
    sleep 30
    echo "Waking up..."
    install_galaxy
}

main

# microk8s helm3 upgrade --install galaxy-project /home/ubuntu/galaxy-helm/galaxy -f /home/ubuntu/galaxy-values.yaml -n galaxy