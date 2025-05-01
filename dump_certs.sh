#!/bin/sh

set -e # Exit on error

ACME_JSON_FILE="/input/acme.json"
OUTPUT_DIR="/output"
CHECK_INTERVAL=3600 # Check every hour (adjust as needed)

echo "Certificate Dumper started."
echo "Watching ${ACME_JSON_FILE} for changes..."
echo "Outputting PEM files to ${OUTPUT_DIR}"

# Function to extract certificates
extract_certs() {
    echo "Change detected in ${ACME_JSON_FILE} or initial run. Extracting certificates..."
    # Ensure output directory exists
    mkdir -p "${OUTPUT_DIR}"

    # Check if jq is installed
    if ! command -v jq > /dev/null; then
        echo "Error: jq is not installed. Please install it in the Docker image."
        exit 1
    fi

    # Extract domains and certificates/keys
    # Adjust the resolver name 'letsencrypt' if yours is different in acme.json
    jq -r '.letsencrypt.Certificates[] | .domain.main + " " + .certificate + " " + .key' < "${ACME_JSON_FILE}" | while read -r domain cert key; do
        DOMAIN_DIR="${OUTPUT_DIR}/${domain}"
        mkdir -p "${DOMAIN_DIR}"

        echo "Extracting cert for ${domain}..."
        echo "${cert}" | base64 -d > "${DOMAIN_DIR}/fullchain.pem"
        echo "${key}" | base64 -d > "${DOMAIN_DIR}/privkey.pem"
        chmod 644 "${DOMAIN_DIR}/fullchain.pem"
        chmod 600 "${DOMAIN_DIR}/privkey.pem" # Key should be less accessible
        echo "Certificates for ${domain} extracted to ${DOMAIN_DIR}"
    done
    echo "Extraction complete."
}

# Initial extraction
extract_certs

# Watch for changes (simple polling method)
last_modified=$(stat -c %Y "${ACME_JSON_FILE}")
while true; do
    sleep "${CHECK_INTERVAL}"
    current_modified=$(stat -c %Y "${ACME_JSON_FILE}")
    if [ "${current_modified}" -ne "${last_modified}" ]; then
        echo "Change detected, re-extracting..."
        extract_certs
        last_modified="${current_modified}"
    # else # Optional: uncomment for verbose logging
    #    echo "No changes detected."
    fi
done