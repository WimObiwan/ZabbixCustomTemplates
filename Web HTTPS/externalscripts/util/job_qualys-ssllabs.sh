#!/bin/bash

# You can run this script in a cron job, e.g. every 10 minutes

WORKINGFOLDER="/var/lib/zabbix/check_qualys-ssllabs/"

#Precaution... To prevent malicious file deletions...
cd "$WORKINGFOLDER"

# Interval between checks
AGE_THRESHOLD=$((7 * 24 * 3600))

# There are 3 files
#   req-*   Request file (empty file to trigger request check, being created by externalcheck)
#   rsp-*   Response file (response, being read by externalcheck)

# Enumerate REQ file, order by date
for REQ in `ls -tr ${WORKINGFOLDER}req-*`
do
	#REQ=$(find "$WORKINGFOLDER" -maxdepth 1 -name "req-*" -type f | xargs ls -tr | head -1)
	##echo "Qualys SSL Labs: $REQ"

	RSP="${REQ//\/req-/\/rsp-}"

	if [ -f "$RSP" ]; then
		AGE=$(($(date +%s) - $(date +%s -r "$RSP")))
	else
		AGE=-1
	fi

	##echo "Qualys SSL Labs: $AGE"

	HOST="${REQ//*\/req-/}"

	if [[ $AGE -eq -1 ]] || [[ $AGE -ge $AGE_THRESHOLD ]]; then

		# Remove request file
		rm "$REQ"

		echo "Qualys SSL Labs: Checking $HOST"
		RESULT=$(curl -s "https://api.ssllabs.com/api/v3/analyze?host=$HOST&maxAge=1&fromCache=on")
		STATUS=$(echo "$RESULT" | jq -r '.status')
		##echo "Qualys SSL Labs: Checking $HOST - Status $STATUS"

		# Wait till finished
		while [[ "$STATUS" != "READY" ]] && [[ "$STATUS" != "ERROR" ]];
		do
			sleep 10

			RESULT=$(curl -s "https://api.ssllabs.com/api/v3/analyze?host=$HOST&maxAge=1")
			STATUS=$(echo "$RESULT" | jq -r '.status')
			##echo "Qualys SSL Labs: Checking $HOST - Status $STATUS"
		done

		if [[ "$STATUS" == "READY" ]]; then
			echo "$RESULT" > "$RSP"
		fi

		exit 0
	fi
done
