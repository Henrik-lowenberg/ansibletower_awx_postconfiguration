!#/bin/bash
#---------------------------------
# Ansible Tower Post-Configuration tasks
#---------------------------------
#Activate Tower with license key received in email from Red Hat

# Add the user in Red Hat IDM that Tower will use to verify other users to RH IDM (done on IDM replica)
kinit admin
ipa user-add tower
ipa group-add tower_users
ipa group-add-member tower_users --users=tower
ipa user-mod tower --password
#Password: tower
#Enter Password again to verify: tower
#---------------------
#Modified user "tower"
#---------------------
#  User login: tower
#  First name: ansible
#  Last name: tower
#  Home directory: /home/tower
#  Login shell: /bin/bash
#  Principal name: tower@IDM.EXAMPLE.COM
#  Principal alias: tower@IDM.EXAMPLE.COM
#  Email address: tower@example.com
#  UID: 718200020
#  GID: 718200020
#  Account disabled: False
#  Password: True
#  Member of groups: tower_users, ipausers
#  Kerberos keys available: True

# verify that you can lookup user or exit script
ldapsearch -p 389 -h mytowerhost1.idm.example.com  -D "uid=tower,cn=users,cn=accounts,dc=idm,dc=example,dc=com" -w myprincipalpassword -b "dc=idm,dc=example,dc=com" -s sub "(objectclass=*)"
[[ $? != 0 ]] && exit 1

#---------------------------------

#join Tower server to IDM as client, add to IDM node group
#change from false to true in krb5.conf in case of trust to MS AD:
#  dns_lookup_realm = false
#  dns_lookup_kdc = false

# Add ansible user in IDM to "User Administrator" role
# login to server as ansible user
#generate ssh key
#$ ssh-keygen -t rsa

#Add ssh public keys to ansible user in IDM
#Add allow_ansible_user_high_hbac to HBAC rules in IDM, select "All Hosts"

sed -i 's/remote_user*/remote_user = ansible/' /etc/ansible/ansible.cfg

# install CLI and make decoding vaults faster
pip3 --proxy proxyuser:proxypwd@webproxy.example.com:8080 install ansible-tower-cli cryptography

# Create organization
tower-cli organization create --name myorg --description "My Organization"
tower-cli organization delete --name Default

# base config
tower-cli config host mytowerhost1.idm.example.com
tower-cli config username admin
tower-cli config password towerpwd
tower-cli config verify_ssl false

tower-cli team create --name team1 --description "Team 1 responsible for app 1"
tower-cli team create --name team2 --description "Team 2 responsible for app 2"
tower-cli team create --name team3 --description "Team 3 responsible for app 3"

# Create GIT credentials
tower-cli config credential create --name "git_repo1_cred" --organization "myorg" --credential_type "Source Control" --inputs '{"password": "gituser1"}' --user gituser1 --team team1
# paste ssh key in GUI
tower-cli config credential create --name "git_repo2_cred" --organization "myorg" --credential_type "Source Control" --inputs '{"password": "gituser2"}' --user gituser2 --team team2
# paste ssh key in GUI
tower-cli config credential create --name "git_repo3_cred" --organization "myorg" --credential_type "Source Control" --inputs '{"password": "gituser3"}' --user gituser3 --team team3
# paste ssh key in GUI

tower-cli config --global
# settings in /etc/tower/tower_cli.cfg

# create project 
tower-cli projects create --name "ansible-app1-playbooks" --description "application 1 playbooks" --scm_type git --scm_url git@mygitserver.example.com:/repo/ansible-app1-playbooks.git --organization "myorg" --credential "git_repo1_cred" --scm_clean "1" --scm_delete_on_update "1"
tower-cli projects create --name "ansible-app2-playbooks" --description "application 2 playbooks" --scm_type git --scm_url git@mygitserver.example.com:/repo/ansible-app1-playbooks.git --organization "myorg" --credential "git_repo2_cred" --scm_clean "1" --scm_delete_on_update "1"
tower-cli projects create --name "ansible-app3-playbooks" --description "application 3 playbooks" --scm_type git --scm_url git@mygitserver.example.com:/repo/ansible-app1-playbooks.git --organization "myorg" --credential "git_repo3_cred" --scm_clean "1" --scm_delete_on_update "1"

# Create a static inventory
tower-cli inventory create --name "testserver_inventory" --organization "myorg" --description "Inventory to be used for playbook testing"

tower-cli setting list

# Enable Ansible Galaxy
tower-cli setting modify PRIMARY_GALAXY_URL "https://galaxy.ansible.com"
tower-cli setting modify PUBLIC_GALAXY_ENABLED true

# LDAP authorization to Red Hat IDM
tower-cli setting modify AUTH_LDAP_SERVER_URI ldap://idreplica1.idm.example.com
tower-cli setting modify AUTH_LDAP_BIND_DN uid=tower,cn=users,cn=accounts,dc=idm,dc=example,dc=com
tower-cli setting modify AUTH_LDAP_BIND_PASSWORD tower
tower-cli setting modify AUTH_LDAP_GROUP_TYPE MemberDNGroupType
tower-cli setting modify AUTH_LDAP_REQUIRE_GROUP cn=ipausers,OU=Users,dc=idm,dc=example,dc=com
tower-cli setting modify AUTH_LDAP_GROUP_SEARCH "['dc=idm,dc=example,dc=com', 'SCOPE_SUBTREE', '(objectClass=group)']"
tower-cli setting modify AUTH_LDAP_USER_SEARCH "['dc=idm,dc=example,dc=com', 'SCOPE_SUBTREE', '(uid=%(user)s)']"
tower-cli setting modify AUTH_LDAP_USER_DN_TEMPLATE None
tower-cli setting modify AUTH_LDAP_GROUP_TYPE_PARAMS {'member_attr': 'member', 'name_attr': 'cn'}

tower-cli setting list -c 
#Choose from [all, authentication, azuread-oauth2, changed, github, github-org, github-team, google-oauth2, jobs, ldap, logging, named-url, radius, saml, system, tacacsplus, ui]

tower-cli setting list -c all
tower-cli setting list -c ldap
tower-cli setting list -c jobs

# Add a host to an inventory
tower-cli host create --inventory "testserver_inventory" --name testserver1.example.com --variables "{"customer":"somecompany","site":"got","sz":"somecompany_got_test"}"


# Configure proxy 
tower-cli setting modify AWX_TASK_ENV 'HTTPS_PROXY': 'http://proxyuser:proxypassword@webproxy.example.com:8080'

'HTTP_PROXY': 'http://proxyuser:proxypassword@webproxy.example.com:8080', 'https_proxy': 'http://proxyuser:proxypassword@webproxy.example.com:8080', 'http_proxy': 'http://cproxyuser:proxypassword@webproxy.example.com:8080', 'no_proxy': '170.102.136.32/24'}

#Can also be done in Settings > Jobs > "EXTRA ENVIRONMENT VARIABLES"
#{
# "HTTPS_PROXY": "http://cproxyuser:proxypassword@webproxy.example.com:8080",
# "HTTP_PROXY": "http://proxyuser:proxypassword@webproxy.example.com:8080",
# "https_proxy": "http://proxyuser:proxypassword@webproxy.example.com:8080",
# "http_proxy": "http://proxyuser:proxypassword@webproxy.example.com:8080",
# "no_proxy": "170.102.136.32/24"
#}

#---------------------------------
# Tuning
sed -i 's/#pipelining.*/pipelining = True/' /etc/ansible/ansible.cfg
#Change default forks = 5, dependent on no of cores on Tower server(s)



#--------------------------------
#Detailed Examples from internet

#The following commands will create an inventory and user and demonstrate the different role commands on them.
# Create the inventory and list its roles
tower-cli inventory create --name 'test_inventory' --organization 'Default'
tower-cli role list --inventory 'test_inventory'
tower-cli role get --type 'use' --inventory 'test_inventory'
# Create a user, give access to the inventory and take it away
tower-cli user create --username 'test_user' --password 'pa$$' --email 'user@example.com'
tower-cli role grant --type 'use' --user 'test_user' --inventory 'test_inventory'
tower-cli role list --user 'test_user' --type 'use'
tower-cli role revoke --type 'use' --user 'test_user' --inventory 'test_inventory'
# Create a team, give access to the inventory and take it away
tower-cli team create --name 'test_team' --organization 'Default'
tower-cli role grant --type 'use' --team 'test_team' --inventory 'test_inventory'
tower-cli role list --team 'test_team' --type 'use'
tower-cli role revoke --type 'use' --team 'test_team' --inventory 'test_inventory'
# configure LDAP
tower-cli setting modify AUTH_LDAP_SERVER_URI "ldap://ldap.free_dbz.com:3268"
tower-cli setting modify AUTH_LDAP_SERVER_URI @server_uri
tower-cli setting modify AUTH_LDAP_SERVER_URI "ldap://ldap.free_dbz.com:3268"
tower-cli setting modify AUTH_LDAP_BIND_DN "CN=ansible,OU= Accounts,OU=Information Technology,OU=Administration,OU=United States,DC=fedora,DC=red,DC=redhat,DC=com" 
tower-cli setting modify AUTH_LDAP_BIND_PASSWORD "tower"
tower-cli setting modify AUTH_LDAP_START_TLS "false"
tower-cli setting modify AUTH_LDAP_GROUP_TYPE "ActiveDirectoryGroupType"
tower-cli setting modify AUTH_LDAP_REQUIRE_GROUP "CN=APP_APG0_Users,OU=Global Groups,OU=Accounts,DC=fedora,DC=red,DC=free_dbz,DC=com"
tower-cli organization create -n kablam -d "the kablam show"


