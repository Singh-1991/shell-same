#!/bin/bash
 
set -e  # Exit immediately if a command exits with a non-zero status
 
# Define Variables
s3_bucket_name="pnc-trial"
tarball="same_hash_values.tar.gz"
 
# Step 1: Copy tar file from S3 bucket
aws s3 cp s3://$s3_bucket_name/$tarball .
 
# Step 2: Untar the archive
tar -xzvf $tarball
 
# Step 3: Navigate into the untarred directory
cd model_artifacts
 
# File to store calculated MD5 hashes
calculated_md5_file="calculated_md5.txt"
 
# Initialize variables
error_count=0
error_files=""
 
# Function to calculate MD5 hash and append to file
calculate_and_append_md5() {
    local file="$1"
    local md5_value=$(md5sum "$file" | awk '{print $1}')
    echo "$md5_value $file" >> "$calculated_md5_file"
}
 
# Step 4: Remove calculated_md5_file if exists
rm -f "$calculated_md5_file"
 
# Step 5: Calculate MD5 hashes for model_weights.json and control_output.csv
for file in model_weights.json control_output.csv; do
    if [ -f "$file" ]; then
        calculate_and_append_md5 "$file"
    else
        echo "Error: File $file does not exist"
        error_count=$((error_count + 1))
        error_files+=" $file"
    fi
done
 
# Step 6: Compare calculated MD5 hashes with checksum.txt (assuming checksum.txt specifies only model_weights.json and control_output.csv)
while read -r expected_md5 expected_file; do
    if [[ "$expected_file" == "model_weights.json" || "$expected_file" == "control_output.csv" ]]; then
        if [ -f "$expected_file" ]; then
            calculated_md5=$(grep "$expected_file" "$calculated_md5_file" | awk '{print $1}')
            if [ "$calculated_md5" != "$expected_md5" ]; then
                echo "Error: MD5 hash mismatch for $expected_file"
                error_count=$((error_count + 1))
                error_files+=" $expected_file"
            else
                echo "Success: MD5 hash match for $expected_file"
            fi
        else
            echo "Error: File $expected_file mentioned in checksum.txt does not exist"
            error_count=$((error_count + 1))
            error_files+=" $expected_file"
        fi
    fi
done < checksum.txt
 
# Step 7: Handle errors if any
if [ $error_count -gt 0 ]; then
    echo "Error: $error_count files have MD5 hash mismatches or are missing:$error_files"
    exit 1
else
    # Step 8: Success if all files match
    echo "Success: All files have matching MD5 hashes"
    exit 0
fi
 
