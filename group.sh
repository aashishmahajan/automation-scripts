#!/bin/bash

# Define the group names
GROUP1="app_dev_reader"
GROUP2="app_dev_reader_ldap2"

# Temporary files to store rolebindings
TEMP_FILE1="/tmp/rolebindings_${GROUP1}.txt"
TEMP_FILE2="/tmp/rolebindings_${GROUP2}.txt"
MISSING_FILE="/tmp/missing_rolebindings_${GROUP2}.txt"

# Ensure oc is available
if ! command -v oc &> /dev/null; then
    echo "Error: 'oc' command not found. Please ensure OpenShift CLI is installed and configured."
    exit 1
fi

# Check if logged into the cluster
if ! oc whoami &> /dev/null; then
    echo "Error: Not logged into an OpenShift cluster. Please run 'oc login' first."
    exit 1
fi

# Function to get rolebindings for a group
get_rolebindings() {
    local group=$1
    local output_file=$2

    # Get all rolebindings across all namespaces for the group
    oc get rolebinding --all-namespaces -o json | \
    jq -r --arg group "$group" '.items[] | select(.subjects[]? | select(.kind=="Group" and .name==$group)) | "\(.metadata.namespace):\(.metadata.name):\(.roleRef.name)"' | \
    sort > "$output_file"

    if [ ! -s "$output_file" ]; then
        echo "No rolebindings found for group $group."
    fi
}

# Get rolebindings for both groups
echo "Fetching rolebindings for group $GROUP1..."
get_rolebindings "$GROUP1" "$TEMP_FILE1"

echo "Fetching rolebindings for group $GROUP2..."
get_rolebindings "$GROUP2" "$TEMP_FILE2"

# Compare rolebindings and find missing ones for GROUP2
echo "Comparing rolebindings..."
comm -23 "$TEMP_FILE1" "$TEMP_FILE2" > "$MISSING_FILE"

# Display results
if [ -s "$MISSING_FILE" ]; then
    echo "Rolebindings present in $GROUP1 but missing in $GROUP2:"
    echo "-----------------------------------------------------"
    echo "Namespace:RoleBinding:Role"
    cat "$MISSING_FILE"
else
    echo "No missing rolebindings for $GROUP2 compared to $GROUP1."
fi

# Clean up temporary files
rm -f "$TEMP_FILE1" "$TEMP_FILE2" "$MISSING_FILE"

exit 0
