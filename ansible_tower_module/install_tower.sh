#!/bin/bash
sudo yum install epel-release -y
sudo yum install ansible -y

cd ~
wget https://releases.ansible.com/ansible-tower/setup/ansible-tower-setup-latest.tar.gz
tar xvzf ansible-tower-setup-latest.tar.gz
cd ansible-tower-setup-3.8.5-3

cat <<EOF >inventory
    [tower]
    localhost ansible_connection=local

    [automationhub]

    [database]

    [all:vars]
    admin_password='Sang@123'

    pg_host=''
    pg_port=''

    pg_database='awx'
    pg_username='awx'
    pg_password='Sang@123'
    pg_sslmode='prefer'  # set to 'verify-full' for client-side enforced SSL


    automationhub_admin_password=''

    automationhub_pg_host=''
    automationhub_pg_port=''

    automationhub_pg_database='automationhub'
    automationhub_pg_username='automationhub'
    automationhub_pg_password=''
    automationhub_pg_sslmode='prefer'
EOF
chmod a+x setup.sh
sudo sh setup.sh
