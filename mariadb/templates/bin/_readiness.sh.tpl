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

set -ex

SLEEP_TIMEOUT=3

# loop forever
while [ 1 ]
do

    mysql --host=localhost --port="{{ .Values.network.port.mariadb }}" --user=root --password="{{ .Values.database.root_password }}" -e'show databases;'  > /dev/null  2> /dev/null


    STATUS=$?
    if [ $STATUS -eq 0 ]; then

        # mysql is fine and return success
        /bin/echo "Service OK"
        exit 0
    else
        # mysql service is unavailable and keep looping
        /bin/echo "Service Unavailable"

    fi


    # check x amount of seconds
    sleep $SLEEP_TIMEOUT
done