#!/bin/bash

function install_nfs(){
    sudo apt-get install nfs-kernel-server -y

    sudo mkdir -p /srv/nfs
    sudo chown nobody:nogroup /srv/nfs
    sudo chmod 0777 /srv/nfs

    local_ip=$(hostname -I | awk '{print $1}')
    kube_ip=$(hostname -I | awk '{print $2}')
    subnet_local_ip=$(echo $local_ip | awk -F. '{print $1"."$2".0.0/16"}')
    subnet_kube_ip=$(echo $kube_ip | awk -F. '{print $1"."$2".0.0/16"}')
    sudo mv /etc/exports /etc/exports.bak
    echo "/srv/nfs $subnet_local_ip(rw,sync,no_subtree_check,no_root_squash,insecure) $subnet_kube_ip(rw,sync,no_subtree_check,no_root_squash,insecure)" | sudo tee /etc/exports

    sudo systemctl restart nfs-kernel-server
}

function install_microk8s(){
    echo "Installing MicroK8s..."
    sudo apt update && sudo apt upgrade -y
    sudo snap install microk8s --classic --channel=1.30/stable
    sudo microk8s status --wait-ready

    sudo ufw allow in on cni0 && sudo ufw allow out on cni0
    sudo ufw default allow routed
    sudo usermod -a -G microk8s ubuntu
    sudo mkdir -p /home/ubuntu/.kube               
    sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube  
    echo "MicroK8s installed successfully" 
}

function install_csi_nfs_driver(){
    microk8s helm3 repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
    microk8s helm3 repo update

    microk8s helm3 install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
    --namespace kube-system \
    --set kubeletDir=/var/snap/microk8s/common/var/lib/kubelet

    microk8s kubectl wait pod --selector app.kubernetes.io/name=csi-driver-nfs --for condition=ready --namespace kube-system

    local_ip=$(hostname -I | awk '{print $1}')

    echo "Creating NFS storage class"
    cat <<EOF > nfs-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs
provisioner: nfs.csi.k8s.io
parameters:
  server: $local_ip   
  share: /srv/nfs
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
  - hard
  - nfsvers=4.1
EOF

    cat <<EOF > nfs-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cvmfs-alien-cache
  namespace: kube-system
spec:
  storageClassName: nfs
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 25Gi
EOF

    microk8s kubectl create namespace galaxy
    microk8s kubectl apply -f nfs-storage-class.yaml
    microk8s kubectl apply -f nfs-pvc.yaml
    echo "NFS storage class created successfully"
    echo "NFS driver installed successfully"
}

function alias_microk8s() {
    if [[ $SHELL == *"bash"* ]]; then
        config_file="/home/ubuntu/.bashrc"
    elif [[ $SHELL == *"zsh"* ]]; then
        config_file="/home/ubuntu/.zshrc"
    else
        echo "Unsupported shell. Please use bash or zsh."
        return 1
    fi

    if grep -q "alias kubectl=" "$config_file" && grep -q "alias helm=" "$config_file"; then
        echo "Aliases already exist in $config_file"
    else
        echo "alias kubectl='microk8s kubectl'" >> "$config_file"
        echo "alias helm='microk8s helm3'" >> "$config_file"
        echo "Aliases added to $config_file"

        source "$config_file"
        echo "Configuration reloaded. You can now use 'kubectl' and 'helm'."
    fi
}

function setup_microK8s(){    
    echo "Setting up MicroK8s..."
    microk8s enable helm
    microk8s enable host-storage
    microk8s enable dns
    microk8s enable ingress
    microk8s enable registry
    alias_microk8s

    sudo ln -s /var/snap/microk8s/common/var/lib/kubelet /var/lib/kubelet
    echo "MicroK8s setup completed"
}

function update_ip_in_kubeconfig() {
    echo "Updating public IP in kubeconfig file"
    public_ip=$(curl -s ifconfig.me)
    kubeconfig_file="/var/snap/microk8s/current/credentials/client.config"
    new_kubeconfig_path="/home/ubuntu/.kube/config-public"

    if [ -z "$public_ip" ]; then
        echo "Failed to retrieve public IP."
        exit 1
    fi

    if [ -f "$kubeconfig_file" ]; then
        sudo cp "$kubeconfig_file" "$new_kubeconfig_path"
        sudo sed -i "s/server: https:\/\/[0-9.]\+/server: https:\/\/$public_ip/" "$new_kubeconfig_path"
        sudo chown ubuntu:ubuntu "$new_kubeconfig_path"
        echo "Public IP ($public_ip) added to the kubeconfig file"
    else
        echo "kubeconfig file not found"
        exit 1
    fi
}

function update_ip_in_microk8s_config(){
    echo "Updating public IP in MicroK8s configuration"
    public_ip=$(curl -s ifconfig.me)
    config_file="/var/snap/microk8s/current/certs/csr.conf.template"

    if [ -z "$public_ip" ]; then
        echo "Failed to retrieve public IP."
    exit 1
    fi

    sudo sed -i "/#MOREIPS/a IP.3 = $public_ip" "$config_file"
    echo "Public IP ($public_ip) added to the configuration as IP.3"
}

function microk8s_refresh(){
    echo "Refreshing MicroK8s..."
    sudo microk8s refresh-certs
    sudo microk8s stop
    sudo microk8s start
    echo "MicroK8s refreshed successfully"
}

function install_cvmfs(){
    echo "Installing CVMFS on K8s..."
    git clone https://github.com/lablytics/cvmfs-csi /home/ubuntu/cvmfs-csi
    microk8s helm3 install cvmfs /home/ubuntu/cvmfs-csi/deployments/helm/cvmfs-csi -n kube-system -f /home/ubuntu/cvmfs-values.yaml
    echo "CVMFS installed successfully"
}

function install_galaxy(){
    echo "Installing Galaxy on K8s..."
    #microk8s kubectl create namespace galaxy
    microk8s kubectl apply -f /home/ubuntu/galaxy-pvc.yaml 
    
    git clone https://github.com/galaxyproject/galaxy-helm.git /home/ubuntu/galaxy-helm
    cd /home/ubuntu/galaxy-helm/galaxy
    sudo microk8s helm3 dependency update
    microk8s helm3 install -n galaxy galaxy-project /home/ubuntu/galaxy-helm/galaxy -f /home/ubuntu/galaxy-values.yaml --timeout 0m30s
    echo "Galaxy installed successfully"
}

function main() {
    install_microk8s
    install_nfs
    setup_microK8s
    install_csi_nfs_driver
    update_ip_in_microk8s_config
    update_ip_in_kubeconfig
    microk8s_refresh
}

main