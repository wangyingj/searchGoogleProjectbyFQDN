#!/bin/bash

# Script to resolve FQDNs to IPs and search for them in GCP organization
# Created: Wednesday, June 4, 2025
# Author: wangyingj

# Define single log file
LOG_FILE="fqdn_ip_search_results_$(date +%Y%m%d_%H%M%S).log"

echo "FQDN Resolution and GCP Asset Search Results" > $LOG_FILE
echo "Script execution started at: $(date)" >> $LOG_FILE
echo "=========================================" >> $LOG_FILE

# Prompt for organization ID
read -p "Enter GCP Organization ID (e.g., 111111111111): " ORG_ID

# Validate organization ID (basic validation - should be numeric)
if ! [[ "$ORG_ID" =~ ^[0-9]+$ ]]; then
echo "Error: Organization ID should be numeric." | tee -a $LOG_FILE
exit 1
fi

echo "Using GCP Organization ID: $ORG_ID" | tee -a $LOG_FILE
echo "=========================================" >> $LOG_FILE

# Prompt for FQDN list
echo "Enter FQDNs to search (comma-separated, e.g., example1.com,example2.com):"
read FQDN_INPUT

# Convert comma-separated input to array
IFS=',' read -ra FQDNS <<< "$FQDN_INPUT"

# Validate that we have at least one FQDN
if [ ${#FQDNS[@]} -eq 0 ]; then
echo "Error: No FQDNs provided." | tee -a $LOG_FILE
exit 1
fi

# Trim whitespace from each FQDN
for i in "${!FQDNS[@]}"; do
FQDNS[$i]=$(echo "${FQDNS[$i]}" | xargs)
done

echo "Number of FQDNs to process: ${#FQDNS[@]}" | tee -a $LOG_FILE
echo "FQDNs to process:" >> $LOG_FILE
for fqdn in "${FQDNS[@]}"; do
echo "  - $fqdn" >> $LOG_FILE
done
echo "=========================================" >> $LOG_FILE

# Counter for progress tracking
TOTAL=${#FQDNS[@]}
COUNTER=0

# Process each FQDN
for fqdn in "${FQDNS[@]}"; do
COUNTER=$((COUNTER+1))

# Use dig to resolve the FQDN to IP
ip=$(dig +short $fqdn A | grep -v '\.$' | head -1)

if [ -z "$ip" ]; then
    echo "Searching for IP address: $fqdn(No IP found)" | tee -a $LOG_FILE
    echo "Could not resolve FQDN to an IP address" >> $LOG_FILE
    echo "----------------------------------------" >> $LOG_FILE
    continue
fi

# Output in the requested format
echo "Searching for IP address: $fqdn($ip)" | tee -a $LOG_FILE
echo "Command: gcloud asset search-all-resources --scope='organizations/$ORG_ID' --query='$ip' --order-by='createTime'" >> $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE

# Execute the gcloud command and save output
result=$(gcloud asset search-all-resources \
  --scope="organizations/$ORG_ID" \
  --query="$ip" \
  --order-by='createTime' 2>&1)

# Check if results were found and save appropriately
if [[ "$result" == *"Listed 0 items."* ]]; then
    # No results found, log as is
    echo "$result" >> $LOG_FILE
else
    # Results found, extract only the first parentFullResourceName
    echo "Results found for IP $fqdn($ip):" >> $LOG_FILE
    first_result=$(echo "$result" | grep "parentFullResourceName:" | head -1)
    echo "$first_result" >> $LOG_FILE
fi

echo "----------------------------------------" >> $LOG_FILE

# Add a small delay to avoid rate limiting
sleep 2
done

echo "Script execution completed at: $(date)" >> $LOG_FILE
echo "All results saved to $LOG_FILE"
