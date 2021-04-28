#!/bin/bash

function check_dependencies() {

    DEPENDENCIES=(ibmcloud)
    check_connectivity
    for i in "${DEPENDENCIES[@]}"
    do
        if ! command -v "$i" &> /dev/null; then
            echo "$i could not be found, exiting!"
            exit
        fi
    done
}

function check_connectivity() {

    if ! curl --output /dev/null --silent --head --fail http://cloud.ibm.com; then
        echo
        echo "ERROR: please, check your internet connection."
        exit 1
    fi
}

function authenticate() {
    
    local APY_KEY="$1"
    
    if [ -z "$APY_KEY" ]; then
        echo "API KEY was not set."
        exit
    fi
    ibmcloud login --no-region --apikey "$APY_KEY" > /dev/null 2>&1
}

function check_apikeys() {

	INPUT="$(pwd)"/api-keys

	while IFS= read -r line; do
		IBMCLOUD_ACCOUNT=$(echo "$line" | awk -F ':' '{print $1}')
		API_KEY=$(echo "$line" | awk -F ':' '{print $2}')

		if [ -z "$IBMCLOUD_ACCOUNT" ]; then
	  		echo
	   		echo "ERROR: IBM Cloud Name was not set."
	   		echo "       check the $INPUT file and try again."
	   		echo
	   		exit 1
		fi
		if [ -z "$API_KEY" ]; then
	  		echo
	   		echo "ERROR: the API key for the $IBMCLOUD_ACCOUNT IBM Cloud account was not set."
	   		echo "       check the $INPUT file and try again."
	   		echo
	   		exit 1
		fi
	done < "$INPUT"
}

function run() {

    check_dependencies
    check_connectivity

    # usage reports are available only after 2018-01
    YEARS=(2018 2019 2020 2021)

    # only executes if the api-keys is not empty
	if [ -s "$(pwd)"/api-keys ]; then
        # read the API Keys from its files, the file format is
        # <IBM Cloud account name:API Key>

        check_apikeys

        IFS=$'\n' read -d '' -r -a API_KEYS < "$(pwd)"/api-keys

        LAST_MONTH=12
        CURRENT_MONTH_NUMBER=$(date +%m)
        CURRENT_YEAR=$(date +"%Y")

        # creates an empty directory
        if [ -d "./powervs-usage" ]; then 
            rm -rf "powervs-usage"; 
        fi
        mkdir -p ./powervs-usage

        for key in "${API_KEYS[@]}"; do
            ACCOUNT_NAME=$(echo "$key" | awk -F ':' '{print $1}')
            API_KEY=$(echo "$key" | awk -F ':' '{print $2}')
            echo "Collecting usage data for the $ACCOUNT_NAME account."
            authenticate "$API_KEY"
            # creates a dedicated directory for each account
            mkdir -p ./powervs-usage/"$ACCOUNT_NAME"
            for year in "${YEARS[@]}"; do
                # creates a dedicated directory for each year
                mkdir -p ./powervs-usage/"$ACCOUNT_NAME"/"$year"
                if [ "$year" == "$CURRENT_YEAR" ]; then
                    CURRENT_MONTH_NUMBER=$(date +%m)
                    for month in $(seq "$CURRENT_MONTH_NUMBER" 1); do
                        if [[ "$month" -ge 1 ]] && [[ "$month" -le 9 ]]; then
                            month="0"$month
                        fi
                        ibmcloud billing account-usage -d "$year-$month" >> "./powervs-usage/$ACCOUNT_NAME/$year/$month.txt"
                    done
                else
                    for month in $(seq 1 $LAST_MONTH); do
                        if [[ $month -ge 1 ]] && [[ $month -le 9 ]]; then
                            month="0"$month
                        fi
                        ibmcloud billing account-usage -d "$year-$month" >> "./powervs-usage/$ACCOUNT_NAME/$year/$month.txt"
                    done
                fi
            done
        done
	else
		echo
		echo "ERROR: ensure you have added the API Keys at ./api-keys."
		echo
		exit 1
	fi
}

run "$@"
