# Function to download AARopa dependencies
function aaropa-download
{
    # Ensure the script is in the correct directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Run the download.sh script in the same directory
    if [ -f "$SCRIPT_DIR/download.sh" ]; then
        echo "Running download.sh from $SCRIPT_DIR..."
        bash "$SCRIPT_DIR/download.sh"
    else
        echo "Error: download.sh not found in the directory."
        return 1
    fi
}
