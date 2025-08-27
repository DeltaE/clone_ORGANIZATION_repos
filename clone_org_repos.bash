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

echo "📁 Creating master folder: $MASTER_FOLDER"

echo "📁 Creating master folder: $MASTER_FOLDER"

# Set master folder name from config or default
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MASTER_FOLDER_BASE="${MASTER_FOLDER:-cloned_repos}"
ORG_FOLDER="${ORG_NAME}_${TIMESTAMP}"
MASTER_FOLDER="$MASTER_FOLDER_BASE/$ORG_FOLDER"

echo "📁 Creating master folder: $MASTER_FOLDER"
mkdir -p "$MASTER_FOLDER"

# Function to get repositories
get_repos() {
    local org="$1"
    local page=1
    local all_repos=()
    
    echo "🔍 Fetching repositories for $org..."
    
    while true; do
        local url="$API_URL/$org/repos?page=$page&per_page=100"
        local headers=""
        
        if [ -n "$GITHUB_TOKEN" ]; then
            headers="-H \"Authorization: token $GITHUB_TOKEN\""
        fi
        
        local response
        response=$(eval curl -s $headers "$url" 2>/dev/null)
        
        if [[ "$response" == *"\"message\": \"Not Found\""* ]]; then
            echo "❌ Organization '$org' not found"
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
    
    echo "✅ Found ${#all_repos[@]} repositories"
    printf '%s\n' "${all_repos[@]}"
}

# Function to clone repositories
clone_repos() {
    local repos=("$@")
    local successful=0
    local failed=0
    
    echo ""
    echo "🚀 Cloning ${#repos[@]} repositories into $MASTER_FOLDER"
    
    for i in "${!repos[@]}"; do
        local repo_url="${repos[$i]}"
        local repo_name=$(basename "$repo_url" .git)
        local num=$((i + 1))
        
        printf "[%d/%d] Cloning %s... " "$num" "${#repos[@]}" "$repo_name"
        
        if git clone "$repo_url" "$MASTER_FOLDER/$repo_name" &>/dev/null; then
            echo "✅"
            ((successful++))
        else
            echo "❌"
            ((failed++))
        fi
    done
    
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
    
    # Get repositories
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