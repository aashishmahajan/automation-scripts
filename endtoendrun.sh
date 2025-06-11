#!/bin/bash

# Temporary files to store groups and rolebindings
TEMP_GROUP_FILE="/tmp/all_groups.txt"
TEMP_FILE1="/tmp/rolebindings_base.txt"
TEMP_FILE2="/tmp/rolebindings_ldap2.txt"
MISSING_FILE="/tmp/missing_rolebindings.txt"

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

# Step 1: Query all groups and store them
echo "Querying all groups in the cluster..."
oc get groups -o name | sed 's/^group\///' | sort > "$TEMP_GROUP_FILE"

# Step 2: Extract non-_ldap2 groups (groups without _ldap2 suffix)
NON_LDAP2_GROUPS=$(grep -v '_ldap2$' "$TEMP_GROUP_FILE")

# Check if any non-_ldap2 groups exist
if [ -z "$NON_LDAP2_GROUPS" ]; then
    echo "No non-_ldap2 groups found in the cluster."
    rm -f "$TEMP_GROUP_FILE"
    exit 1
fi

# Step 3: Process each non-_ldap2 group
echo "Processing groups for rolebinding comparison..."
found_missing=false

while IFS= read -r BASE_GROUP; do
    LDAP2_GROUP="${BASE_GROUP}_ldap2"

    # Check if the equivalent _ldap2 group exists
    if grep -Fx "$LDAP2_GROUP" "$TEMP_GROUP_FILE" > /dev/null; then
        echo "Comparing groups: $BASE_GROUP and $LDAP2_GROUP"

        # Get rolebindings for both groups
        get_rolebindings "$BASE_GROUP" "$TEMP_FILE1"
        get_rolebindings "$LDAP2_GROUP" "$TEMP_FILE2"

        # Compare rolebindings and find missing ones for LDAP2_GROUP
        comm -23 "$TEMP_FILE1" "$TEMP_FILE2" > "$MISSING_FILE"

        # Display results for this group pair
        if [ -s "$MISSING_FILE" ]; then
            found_missing=true
            echo "Rolebindings present in $BASE_GROUP but missing in $LDAP2_GROUP:"
            echo "-----------------------------------------------------"
            echo "Namespace:RoleBinding:Role"
            cat "$MISSING_FILE"
            echo ""
        else
            echo "No missing rolebindings for $LDAP2_GROUP compared to $BASE_GROUP."
            echo ""
        fi
    else
        echo "Equivalent _ldap2 group '$LDAP2_GROUP' not found for base group '$BASE_GROUP'. Skipping comparison."
        echo ""
    fi
done <<< "$NON_LDAP2_GROUPS"

# Step 4: Summary
if [ "$found_missing" = true ]; then
    echo "Comparison complete. Some missing rolebindings were found (see above)."
else
    echo "Comparison complete. No missing rolebindings found for any _ldap2 groups."
fi

# Clean up temporary files
rm -f "$TEMP_GROUP_FILE" "$TEMP_FILE1" "$TEMP_FILE2" "$MISSING_FILE"

exit 0
