Generate key for SSH connection

`ssh-keygen -t rsa -b 4096 -f ~/.ssh/my_ansible_key`

Create VM using terraform

`cd ias`

`terraform init`

`terraform apply -var "ssh_public_key_path=~/.ssh/my_ansible_key.pub"` 

Execute Ansible playbook
`cd ansible`

`ansible-playbook -i <tf.output.instance_public_ip>, replace_var_with_lvm.yml --extra-vars "ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my_ansible_key"`


```shell
sudo add-apt-repository -y ppa:jblgf0/python
sudo apt-get update
sudo apt-get install python3.6
sudo ln -sf /usr/bin/python3.9 /usr/bin/python3 
sudo apt-get install python-apt
```