#!/bin/bash
export AZURE_HTTP_USER_AGENT='pid-5a91ff6a-52b4-4e6e-92c8-1f47c8e9b9c6'

function quit_on_err {
	echo $1			  			  
	exit 
}
		   
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


echo -e "\n\n"
echo -e "   ___ _    ___  _   _ ___  ___ _  _ ___ __  __"
echo -e "  / __| |  / _ \| | | |   \/ __| || | __| |  | |  "
echo -e " | (__| |_| (_) | |_| | |) \__ \ __ | _|| |__| |__"
echo -e "  \___|____\___/ \___/|___/|___/_||_|___|____|____|\n\n\n"


echo -e "$GREEN Please wait while we setup the integration with your Azure account. $NC \n\n"
echo -e "This script grants CloudShell permissions to your Azure account."
#========================================================================================
x=$(az account list)
accountname=$(az account show |jq -r .user.name)
length=$(jq -n "$x" | jq '. | length')
END=$length-1
i=0
declare -i subscription_number=0

if [ "$length" -eq 0 ]
then
        echo -e "${RED}Error no subscription found${NC}"
        exit 1
fi

if [ "$length" -eq 1 ]
then
        subscription_number=1
else 
        echo "Please type subscription number:#"
        while [[ $i -le $END ]]
        do
                # prints subscription name and id
                echo "$((i+1))" $(jq -n "$x" | jq .["$i"].name )  $(jq -n "$x" | jq .["$i"].id )
                ((i++))
        done

        read -p  "Please enter number between 1 to $length: " subscription_number

        while [  $subscription_number -lt 1 -o $subscription_number -gt $length ]
        do	
                read -p "Please enter number between 1 to $length: " subscription_number
        done
fi

SubscriptionId=$(jq -n "$x" | jq .["$((subscription_number-1))"].id -r)

az account set --subscription $SubscriptionId

echo -e "Running with settings:"
echo -e "Subscription:" $GREEN$(jq -n "$x" | jq .["$((subscription_number-1))"].name )  $SubscriptionId$NC

#========================================================================================



#creating a random key
CLOUDSHELL_RANDOM=$(date +%s | sha256sum | base64 | head -c 12;echo)$(echo $RANDOM)
CLOUDSHELL_RANDOM="$(echo $CLOUDSHELL_RANDOM | tr '[A-Z]' '[a-z]')"
AppName=$(echo "CLOUDSHELL-"$CLOUDSHELL_RANDOM)
TenantId=$(az account show --query tenantId -o tsv)


echo -e "Creating AD application for CloudShell"
AppKey=$(az ad sp create-for-rbac -n $AppName | jq -r '.password') ||  quit_on_err "The user that runs the script should be an Owner."
az ad sp credential reset -n $AppName --password $AppKey --end-date '2299-12-31'

AppId=$(az ad app list $SubscriptionId --display-name $AppName | jq '.[0].appId' | tr -d \")

echo -e "Configuring access to Azure API"
bash -c "cat >> role.json" <<EOL
[{"resourceAppId": "797f4846-ba00-4fd7-ba43-dac1f8f63013","resourceAccess":[{"id": "41094075-9dad-400e-a0bd-54e686782033", "type":"Scope"}]}]
EOL
 
az ad app update --id $AppId --required-resource-accesses role.json
rm role.json

#========================================================================================


echo -e "\n\n-------------------------------------------------------------------------"
echo "Copy the values below and paste them into the relevant attributes of your CloudShell's Azure cloud provider resource"
echo -e "\n${NC}Application ID : ${GREEN}$AppId"
echo -e "${NC}Application Key : ${GREEN}$AppKey"
echo -e "${NC}Tenant ID : ${GREEN}$TenantId"
echo -e "${NC}Subscription ID : ${GREEN}$SubscriptionId"
echo -e "${NC}-------------------------------------------------------------------------\n\n"

                                                                                     
echo -e "Done \n"
