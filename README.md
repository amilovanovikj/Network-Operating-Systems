# Network Operating Systems 2020 Course

This repository is the final project for the course Network Operating Systems, winter semester 2020.

It includes terraform scripts for automating the deployment process on the cloud environment (in this case on Azure cloud) as well as a guide (as part of this README) on how to configure the servers as required by the course assignment.

## Terraform setup

The Terraform files found in this repository create the following resources in a resource group named **Network-Operating-Systems** on Azure cloud:
- A VNet with address space 172.16.32.0/24
- Two subnets on the VNet space:
  - **DC subnet** with address prefix of 172.16.32.0/27 in which the domain controller (DNS/AD server) will reside
  - **VM subnet** with address prefix of 172.16.32.32/27 in which the ftp/mail server and the client server will reside
- Two network security groups (one for each subnet):
  - An NSG that allows inbound RDP traffic from the terraform host to the DC subnet
  - An NSG that allows inbound SSH traffic from the terraform host to the VM subnet
- One Windows 2019 Datacenter virtual machine sized Standard B2s for the domain controller server
- Two Linux (Ubuntu 18.04-LTS) virtual machines sized Standard B1s for the ftp/mail server and the client server
- Three public IP addresses, one for each VM
- Three network interface cards, one for each VM:
  - NIC for the DC server, with private IP association in the DC subnet and one public IP address
  - NIC for the ftp/mail server, with private IP association in the VM subnet and one public IP address
  - NIC for the client server, with private IP association in the DC subnet and one public IP address
- Three OS disks, one for each VM

***

Before starting with terraform commands, create a new resource group named **Network-Operating-Systems** in Azure and a service principal (SPN for short) and give it "Contributor" access on the resource group scope. 
- Use the Azure portal to create an SPN -> search for 'Azure Active Directory' and click the service. Next, go to 'App registrations' in the 'Manage' menu and click on 'New registration'. Type in the SPN name and click 'Register', leaving everything else as default.
- To create a secret for the SPN, again go to the 'App registrations' and select the created SPN. Go to 'Certificates & secrets' in the 'Manage' menu and click on 'New client secret'. Enter a description (something like 'Terraform') and click 'Add'.
- Next, create a resource group from the Azure portal -> search for 'Resource groups' and click the service. Click '+ Create' and specify the name as 'Network-Operating-Systems', and choose the region that is closest to you. Click 'Review + create'.
- Go to the resource group and under the 'Access Control (IAM)' menu click on '+ Add' and 'Add role assignment'. Select the 'Contributor' role, assign access to 'User, group, or service principal' and search for your SPN by its name. Click 'Save'

Refer to [this link](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) if you need further instructions.

To execute the scripts, clone this repository, cd into the directory and run:
```bash
terraform init
```
Make sure you have [Terraform downloaded](https://www.terraform.io/downloads.html) and a **variables.tfvars** file with the required variable values created (check [variables.tf](https://github.com/amilovanovikj/Network-Operating-Systems/blob/main/variables.tf) for more info). Next execute the following command and enter "yes" when promted for confirmation:
```bash
terraform apply --var-file="variables.tfvars"
```
This will spin up the whole environment in a couple of minutes.

#### Note: In order to have access to cloud resources, execute the Terraform commands from the same host that will RDP/SSH into the VMs. This is due to the way Terraform is set up to query http://ipv4.icanhazip.com for the public IP address of the host executing Terraform, and whitelisting this IP address on the RDP/SSH NSG rules.

## DNS/Active Directory setup

In order to set up Active Directory Domain Service, RDP into the windows VM named mos-vm-windows-dc (download the RDP file from the Azure portal and log into the VM with the credentials you specified in your .tfvars file). Then, open PowerShell and run the following commands:

```PowerShell
## AD DS Deployment
Install-WindowsFeature AD-Domain-Services
Import-Module ADDSDeployment
Install-ADDSForest `
  -CreateDnsDelegation:$false `
  -DomainName "yourdomain.you" `
  -DomainNetbiosName "YOURDOMAIN" `
  -DomainMode "WinThreshold" `
  -ForestMode "WinThreshold" `
  -InstallDns:$true `
  -NoRebootOnCompletion:$false `
  -DatabasePath "C:\Windows\NTDS" `
  -LogPath "C:\Windows\NTDS" `
  -SysvolPath "C:\Windows\SYSVOL" `
  -Force:$true

# These commands will restart the VM. 
# Again, RDP into it and open PowerShell to execute the commands that follow.

# Create user in AD. 
# For easier setup, use the same value for SamAccountName and UserPrincipalName
# as the value of the Terraform variable named linux_username
Import-Module ActiveDirectory
New-ADUser `
  -Name "Jane Doe" `
  -GivenName "Jane" `
  -Surname "Doe" `
  -SamAccountName "jane.doe" `
  -UserPrincipalName "jane.doe@yourdomain.you" `
  -Path "CN=Users,DC=yourdomain,DC=you" `
  -Enabled $true `
  -AccountPassword(Read-Host -AsSecureString "Input Password:")

## Create another user for sending emails
New-ADUser `
  -Name "Mail User" `
  -GivenName "Mail" `
  -Surname "User" `
  -SamAccountName "mailuser" `
  -UserPrincipalName "mailuser@yourdomain.you" `
  -Path "CN=Users,DC=yourdomain,DC=you" `
  -Enabled $true `
  -AccountPassword(Read-Host -AsSecureString "Input Password:")
```

After finishing with these PowerShell commands, you have a AD DS set up, with your user added in AD.

## Linux VMs setup

Run the following commands on both Linux VMs (**mos-vm-ubuntu-mail** and **mos-vm-ubuntu-client**) one by one and carefully read the explanation for each command in the comment above it.

```bash
# Apply on fist login to the VM
sudo apt update
sudo apt upgrade -y

## Configure the DNS server
sudo apt install resolvconf

# If on client VM, prepend the local VM private IP address URL mapping to the hosts file
echo -e "172.16.32.36 mos-client.yourdomain.you mos-client\n$(cat /etc/hosts)" | sudo tee /etc/hosts
# If on mail VM, prepend the local VM private IP address URL mapping to the hosts file
echo -e "172.16.32.37 mos-mail.yourdomain.you mos-mail\n$(cat /etc/hosts)" | sudo tee /etc/hosts

# Prepend the DC private IP address URL mapping to the hosts file
echo -e "172.16.32.4 mos-dc.yourdomain.you mos-dc\n$(cat /etc/hosts)" | sudo tee /etc/hosts
# Append the DNS server config in the resolv.conf file generator
echo "domain yourdomain.you
search yourdomain.you
nameserver 172.16.32.4
nameserver 8.8.8.8
" | sudo tee -a /etc/resolvconf/resolv.conf.d/head
# Restart the Ubuntu network service
sudo netplan apply

## Synchronize time with DNS server
sudo apt install ntp -y
# Add the server FQDN to the NTP config file for time synchronization
sed '/^\# Specify one or more NTP servers\.$/a server mos-dc.yourdomain.you' /etc/ntp.conf | sudo tee /etc/ntp.conf
# Restart the network time protocol service
sudo /etc/init.d/ntp restart
```

### Kerberos configuration

Kerberos is a network authentication protocol for Active Directory. The following commands install and configure Kerberos in the following manner:
- By default the initial tickets for authorization will have a lifetime of one day and set the allowable amount of time that the library will tolerate before assuming that a Kerberos message is invalid to 5 minutes.
- Specify **yourdomain.you** as the realm and the default domain. This is how the initial tickets will know your domain.
- Add the domain controller as the admin server and the key distribution center. This is how the Linux VMs will know where to send the authentication requests for AD users.
- Set up Priviledged Access Management (PAM) app with Kerberos in order to isolate the use of privileged accounts and reduce the risk of credentials being stolen.

```bash
# Install required packages
sudo apt install krb5-user libpam-krb5 libpam-ccreds auth-client-config -y

# Back up the default Kerberos setup
sudo cp /etc/krb5.conf /etc/krb5.conf.bak

# Add the following content to the Kerberos config file
echo "[libdefaults]
  default_realm       =           YOURDOMAIN.YOU
  forwardable         =           true
  proxiable           =           true
  dns_lookup_realm    =           true
  dns_lookup_kdc      =           true
 
  [realms]
    YOURDOMAIN.YOU = {
      kdc            =       mos-dc.yourdomain.you
      admin_server   =       mos-dc.yourdomain.you
      default_domain =       YOURDOMAIN.YOU
    }
 
[domain_realm]
  .domain.com = YOURDOMAIN.YOU
  domain.com = YOURDOMAIN.YOU
 
[appdefaults]
  pam = {
    ticket_lifetime         = 1d
    renew_lifetime          = 1d
    forwardable             = true
    proxiable               = false
    retain_after_close      = false
    minimum_uid             = 0
    debug                   = false
  }
" | sudo tee /etc/krb5.conf
```

### Samba configuration

The Linux VMs will need to be configured as Samba domain members in order to use the Active Directory service of the Windows Domain Controller. This set up is crucial for AD compatibility with local services such as the FTP and mail services. This is exactly what the smb.conf file is used for. Run the following commands to set up Samba correctly with AD DS.

```bash
# Install Samba
sudo apt install samba -y

# Back up the default Samba setup
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

# Add the following content to the Samba config file
echo "[global]
   workgroup = YOURDOMAIN
   realm = yourdomain.you
   security = ADS
   encrypt passwords = true
   socket options = TCP_NODELAY
   domain master = no
   local master = no
   preferred master = no
   os level = 0
   domain logons = 0
   server string = %h server (Samba, Ubuntu)
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   syslog = 0
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes
" | sudo tee /etc/samba/smb.conf
```

### Domain join

Finally, use the following commands to join the domain and send an initial ticket with Kerberos to check if the authentication with AD is working.

```bash
## Join the domain. Use the windows administrator user you specified in .tfvars
sudo net ads join -U admin

## Verify authentication for AD
kinit jane.doe@YOURDOMAIN.YOU
klist
```

## FTP and mail server setup

The Linux VM named **mos-vm-ubuntu-mail** will be used as the FTP/Mail server. SSH into the machine using the following command:
```bash
ssh -i <ssh_private_key_file_location> <linux_username>@<public_ip_address>
```
You should have created the ssh key before executing Terraform. Use the same username as the 'linux_username' variable from Terraform. You can find the public IP address of the VM in the Azure portal.

Run the following commands to install the necessary packages and configure the services.

```bash
# Install FTP server package
sudo apt install vsftpd -y
# Back up the default FTP server setup
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
# Modify the FTP config file to disable anonymous access
# and thus require AD authentication for setting up the connection.
# This config will also enable FTP passive mode.
echo "listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=ftp
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
ascii_upload_enable=YES
ascii_download_enable=NO
ftpd_banner=Welcome to your private FTP server.
session_support=YES
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
allow_writeable_chroot=YES
" | sudo tee /etc/vsftpd.conf

# Set up Kerberos authentication for FTP server
echo "auth required pam_listfile.so item=user sense=deny file=/etc/ftpusers onerr=succeed
auth required pam_krb5.so
account required pam_krb5.so
" | sudo tee /etc/pam.d/vsftpd

# Enable and restart the FTP service
sudo systemctl enable vsftpd
sudo systemctl restart vsftpd

## Install mail command and Postfix mail server. Accept defaults when prompted.
sudo apt install mailutils -y
# Edit Postfix config, setting the FTP hostname and allowing FTP for all VMs in the Azure VNet.
( sed '/smtpd_relay_restrictions/q' /etc/postfix/main.cf ;
echo 'myhostname = mos-mail.yourdomain.you
mydomain = yourdomain.you
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain, mail.$mydomain
relayhost =
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.32.16.0/24
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all' ) | sudo tee /etc/postfix/main.cf
```

## Client setup

In order to check if our FTP and mail services are running correctly, we need to have a client VM configured. This is exactly what the **mos-vm-ubuntu-client** VM will be used for. 

The Ubuntu image we used when creating this VM already has FTP client installed on it, so no further configuration is required for this service. For testing the mail server and sending mails from the Mail User to our primary user we will use the alpine mail client.

SSH into the **mos-vm-ubuntu-client** machine (just like with the ftp/mail VM) and execute the following commands:

```bash
# Install the mail client
sudo apt install alpine -y

# Create the mail user on the client VM
sudo useradd -m mailuser

# Switch to the mail user. You will be prompted for the AD password of this user
su - mailuser

# Initialize the mail client for the first time for this user
alpine
# Use the following keys for quickly exiting the configuration:
# E + Q + Y

# Edit the Mail User's Alpine configuration
sed '/personal-name=/s/$/Anonymous mail user/;
/user-domain=/s/$/yourdomain\.you:25\/user=mailuser@yourdomain\.you/;
/smtp-server=/s/$/mos-mail/;
/literal-signature=/s/$/Kind regards,\\nAnonymous mail user\\n/' ~/.pinerc > temp
mv temp ~/.pinerc

# Switch back to your default Linux user
exit
```

