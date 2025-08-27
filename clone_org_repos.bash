#!/bin/bash
# Simple script to clone all repositories from a GitHub organization
# Creates a timestamped folder with all repos inside
# Usage: ./clone_org_repos.sh [organization_name]


# Load config file
CONFIG_FILE="config.env"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️ Config file $CONFIG_FILE not found. Using default API URL and org name."
    API_URL="https://api.github.com/orgs"
    ORG_NAME="DeltaE"
fi

# Allow override from command line argument
ORG_NAME="${1:-$ORG_NAME}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Set master folder name from config or default
MASTER_FOLDER_BASE="${MASTER_FOLDER:-cloned_repos}"
ORG_FOLDER="$ORG_NAME"
MASTER_FOLDER="$MASTER_FOLDER_BASE/$ORG_FOLDER"

echo "📁 Target folder: $MASTER_FOLDER"
mkdir -p "$MASTER_FOLDER"

# Create timestamp summary file
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "========================================" > "$MASTER_FOLDER/clone_summary.txt"
echo "CLONE OPERATION SUMMARY" >> "$MASTER_FOLDER/clone_summary.txt"
echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
echo "Organization: $ORG_NAME" >> "$MASTER_FOLDER/clone_summary.txt"
echo "Date/Time: $TIMESTAMP" >> "$MASTER_FOLDER/clone_summary.txt"
echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"

# Function to get repositories
get_repos() {
    local org="$1"
    local page=1
    local all_repos=()
    
    while true; do
        local url="$API_URL/$org/repos?page=$page&per_page=100"
        local headers=""
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers="-H \"Authorization: token $GITHUB_TOKEN\""
        fi
        
        local response
        response=$(eval curl -s $headers "$url" 2>/dev/null)
        
        if [[ "$response" == *"\"message\": \"Not Found\""* ]]; then
            echo "❌ Organization '$org' not found" >&2
            return 1
        fi
        
        local repos
        repos=$(echo "$response" | grep -o '"clone_url": "[^"]*' | cut -d'"' -f4)
        
        if [ -z "$repos" ]; then
            break
        fi
        
        while IFS= read -r repo_url; do
            [ -n "$repo_url" ] && all_repos+=("$repo_url")
        done <<< "$repos"
        
        ((page++))
    done
    
    echo "✅ Found ${#all_repos[@]} repositories" >&2
    printf '%s\n' "${all_repos[@]}"
}

# Function to sync existing repositories
sync_repos() {
    local target_dir="$1"
    local successful=0
    local failed=0
    
    echo ""
    echo "🔄 Syncing existing repositories in $target_dir"
    
    # Update summary file for sync operation
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "" >> "$target_dir/clone_summary.txt"
    echo "SYNC OPERATION - $TIMESTAMP" >> "$target_dir/clone_summary.txt"
    echo "----------------------------------------" >> "$target_dir/clone_summary.txt"
    
    for repo_dir in "$target_dir"/*; do
        if [ -d "$repo_dir/.git" ]; then
            local repo_name=$(basename "$repo_dir")
            printf "Syncing %s... " "$repo_name"
            
            # Try different sync strategies
            if (cd "$repo_dir" && git fetch --all && git pull) &>/dev/null; then
                echo "✅"
                echo "✅ $repo_name (synced)" >> "$target_dir/clone_summary.txt"
                ((successful++))
            elif (cd "$repo_dir" && git fetch --all) &>/dev/null; then
                echo "🔄 (fetched only)"
                echo "🔄 $repo_name (fetched only)" >> "$target_dir/clone_summary.txt"
                ((successful++))
            else
                echo "❌"
                echo "❌ $repo_name (sync failed)" >> "$target_dir/clone_summary.txt"
                ((failed++))
            fi
        fi
    done
    
    echo "----------------------------------------" >> "$target_dir/clone_summary.txt"
    echo "SYNC SUMMARY: $successful successful, $failed failed" >> "$target_dir/clone_summary.txt"
    echo "========================================" >> "$target_dir/clone_summary.txt"
    
    echo ""
    if [ $successful -gt 0 ] || [ $failed -gt 0 ]; then
        echo "📊 Sync Summary: $successful successful, $failed failed"
    else
        echo "📊 No repositories found to sync"
    fi
}

# Function to clone repositories
clone_repos() {
    local repos=("$@")
    local successful=0
    local failed=0
    
    echo ""
    echo "🚀 Cloning ${#repos[@]} repositories into $MASTER_FOLDER"
    
    # Add cloned repos header to summary
    echo "" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "CLONED REPOSITORIES:" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "----------------------------------------" >> "$MASTER_FOLDER/clone_summary.txt"
    
    for i in "${!repos[@]}"; do
        local repo_url="${repos[$i]}"
        local repo_name=$(basename "$repo_url" .git)
        local num=$((i + 1))
        
        printf "[%d/%d] Cloning %s... " "$num" "${#repos[@]}" "$repo_name"
        
        if git clone "$repo_url" "$MASTER_FOLDER/$repo_name" &>/dev/null; then
            echo "✅"
            echo "✅ $repo_name" >> "$MASTER_FOLDER/clone_summary.txt"
            ((successful++))
        else
            echo "❌"
            echo "❌ $repo_name (FAILED)" >> "$MASTER_FOLDER/clone_summary.txt"
            ((failed++))
        fi
    done
    
    # Add summary footer
    echo "----------------------------------------" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "SUMMARY: $successful successful, $failed failed" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
    
    echo ""
    echo "📊 Summary: $successful successful, $failed failed"
}

# Main execution
main() {
    # Check if git is available
    if ! command -v git &> /dev/null; then
        echo "❌ Git is not installed"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        echo "❌ curl is not installed"
        exit 1
    fi
    
    echo "🔄 Cloning all repositories from organization: $ORG_NAME"
    
    # Check if org folder already exists with repos
    if [ -d "$MASTER_FOLDER" ] && [ "$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)" -gt 0 ]; then
        echo "📂 Folder $MASTER_FOLDER already exists with repositories. Syncing instead of cloning."
        sync_repos "$MASTER_FOLDER"
        echo ""
        echo "🎉 All repositories synced in: $(pwd)/$MASTER_FOLDER"
        return 0
    fi
    
    # Get repositories
    echo "🔍 Fetching repositories for $ORG_NAME..."
    local repo_urls
    repo_urls=$(get_repos "$ORG_NAME")
    
    if [ -z "$repo_urls" ]; then
        echo "❌ No repositories found"
        exit 1
    fi
    
    # Convert to array
    local repos_array=()
    while IFS= read -r line; do
        [ -n "$line" ] && repos_array+=("$line")
    done <<< "$repo_urls"
    
    # Clone all repositories
    clone_repos "${repos_array[@]}"
    
    echo ""
    echo "🎉 All repositories cloned in: $(pwd)/$MASTER_FOLDER"
}

main "$@"