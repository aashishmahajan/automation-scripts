```bash
#!/bin/bash

# Define the base group name
BASE_GROUP="app_dev_reader"
LDAP2_GROUP="${BASE_GROUP}_ldap2"

# Temporary files to store rolebindings and groups
TEMP_GROUP_FILE="/tmp/base_groups.txt"
TEMP_FILE1="/tmp/rolebindings_${BASE_GROUP}.txt"
TEMP_FILE2="/tmp/rolebindings_${LDAP2_GROUP}.txt"
MISSING_FILE="/tmp/missing_rolebindings_${LDAP2}_GROUP.txt"

# Ensure oc is available
if ! command -v oc &> /dev/null; then
    echo "ERROR: 'oc' command not found. Please ensure OpenShift CLI installed and configured."
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

# Step 1: Query all groups and check for BASE_GROUP and LDAP2_GROUP
echo "Querying all groups in the cluster..."
oc get groups -o name | sed 's/^group\///' > "$TEMP_GROUP_FILE"

# Check if BASE_GROUP exists
if ! grep -Fx "$BASE_GROUP" "$TEMP_GROUP_FILE" > /dev/null; then
    echo "Error: Base group '$BASE_GROUP' not found in the cluster."
    rm -f "$TEMP_GROUP_FILE"
    exit 1
fi

# Check if LDAP2_GROUP exists
if ! grep -Fx "$LDAP2_GROUP" "$TEMP_GROUP_FILE" > /dev/null; then
    echo "Error: Equivalent LDAP2 group '$LDAP2_GROUP' not found in the cluster."
    rm -f "$TEMP_GROUP_FILE"
    exit 1
fi

# Step 2: Get rolebindings for both groups
echo "Fetching rolebindings for group $BASE_GROUP..."
get_rolebindings "$BASE_GROUP" "$TEMP_FILE1"

echo "Fetching rolebindings for group $LDAP2_GROUP..."
get_rolebindings "$LDAP2_GROUP" "$TEMP_FILE2"

# Step 3: Compare rolebindings and find missing ones for LDAP2_GROUP
echo "Comparing rolebindings..."
comm -23 "$TEMP_FILE1" "$TEMP_FILE2" > "$MISSING_FILE"

# Step 4: Display results
if [ -s "$MISSING_FILE" ]; then
    echo "Rolebindings present in $BASE_GROUP but missing in $LDAP2_GROUP:"
    echo "-----------------------------------------------------"
    echo "Namespace:RoleBinding:Role"
    cat "$MISSING_FILE"
else
    echo "No missing rolebindings for $LDAP2_GROUP compared to $BASE_GROUP."
fi

# Clean up temporary files
rm -f "$TEMP_GROUP_FILE" "$TEMP_FILE1" "$TEMP_FILE2" "$MISSING_FILE"

exit 0
