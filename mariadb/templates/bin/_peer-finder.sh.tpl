#!/usr/bin/env bash
# Copyright 2017 The Openstack-Helm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#set -ex


TOKEN_FILE='/var/run/secrets/kubernetes.io/serviceaccount/token'

# check for 3 arguments

# ./myscript.sh -e conf -s /etc -l /usr/lib /etc/hosts
# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )


# ensure correct command line arguments are passed
if [[ $# -eq 2 ]] ; then
    echo "peer-finder: service $1 found and value of $2 for force cluster"
    SERVICE_NAME=$1
    FORCE_ONLY_MEMBERS=$2
else
    echo 'peer-finder: You need to pass argument <service name> <1|0 for force cluster members>'
    exit 1
fi

# print galera cluster address
while [ 1 ]
do

    # get service endpoint
    URL="https://kubernetes.default.svc.cluster.local/api/v1/namespaces/$NAMESPACE/endpoints/$SERVICE_NAME"
    echo $URL

    # read token file
    TOKEN=$(<$TOKEN_FILE)

    STATUS=$?
    if [ $STATUS -eq 0 ]; then
        echo "token read"
        echo $TOKEN
    else
        echo 'Unable to open a file with token.'
        # not sure if service should be up or keep retrying
        #exit 1
    fi


    # get json output string
    DATA = curl -k -H "Authorization: Bearer $TOKEN" $URL

    startSearching=false # ignore lines in json output until "subsets" found. start searching
    hasAddresses=false # if found subsets, make sure there is 'addresses' section
    seedFound=false # found seed job, get last IP as IP comes before name with seed in it
    lastIP=""
    ips=()
    names=()

    IP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

    while read -r line1; do

        # remove double quotes from line
        line=$(echo $line1 | sed 's/\"//g')

        if [[ $line == *"subsets"* ]]; then
             # found subsets section, start looking for ip addresses
              startSearching=true
        fi

        if [[ $line == *seed* && $FORCE_ONLY_MEMBERS == 0 ]]; then
            # found seed running, so return lastIP only
            echo "--wsrep_cluster_address=gcomm://${lastIP%?}"
            exit 0    #enable production
        fi

        if [[ $line == *ports* ]]; then
              # the line with port has ip address also,
              # so want to skip processing below
              break
        fi

        if [[ $startSearching == true ]]; then
            # reached subsets, starting parsing IP's
            if [[ $line == *addresses* ]]; then
                # making sure we have addresses with IP's
                hasAddresses=true
            fi

            if [[ $line == *ip* ]]; then
                # seems like ip key and actual IP on different line
                # ignore ip key and add actual ip to array

                  do
                      if [[ ! $word =~ ^.ip.:.* ]]; then

                        if [[ $word == IP ]]; then
                            # skip adding current IP to ips list
                            break
                        fi

                        # add ip address to ips list
                        # remove "ip:" from line if it exists
                          ips=("${ips[@]}" $(echo $word | sed 's/ip\://g') )
                          lastIP=$word
                      fi
                  done
              fi
           fi

    done <<< "$DATA"

    if [[ $hasAddresses == true ]]; then
        # loop through IP and add to result string
        RESULT=""
        for i in "${ips[@]}"; do
            RESULT="$RESULT$i"
        done

        # return IP in format = 192.168.120.65,192.168.120.66
        # remove trailing comma
        echo "--wsrep_cluster_address=gcomm://${RESULT%?}"
        exit 0
    fi

done

