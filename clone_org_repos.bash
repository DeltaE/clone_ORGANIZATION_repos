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
            # Final summary
        local total_repos=${#repos_array[@]}
        local cloned_repos=$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)
        echo ""
        echo "🎉 Final Status:"
        echo "📁 Location: $(pwd)/$MASTER_FOLDER"
        echo "📦 Local repositories: $cloned_repos/$total_repos"
        echo "🔓 Public: $org_public | 🔒 Private: $org_private"
        
        # Update summary file with final status
        echo "" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "FINAL STATUS:" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "📦 Local repositories: $cloned_repos/$total_repos" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "🔓 Public: $org_public | 🔒 Private: $org_private" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
        return 0
    fi
    
    # Fresh clone - no existing repos
    print_repo_summary "Cloning All Repositories" "${repos_array[@]}"
    clone_repos "${repos_array[@]}"
    
    # Final summary for fresh clone
    local cloned_repos=$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)
    echo ""
    echo "🎉 All repositories cloned!"
    echo "📁 Location: $(pwd)/$MASTER_FOLDER"
    echo "📦 Cloned: $cloned_repos/$org_total repositories"
    echo "🔓 Public: $org_public | 🔒 Private: $org_private"
    
    # Update summary file with final status
    echo "" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "FINAL STATUS:" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "📦 Cloned: $cloned_repos/$org_total repositories" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "🔓 Public: $org_public | 🔒 Private: $org_private" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt""
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

# Function to calculate repository statistics
get_repo_stats() {
    local repos=("$@")
    local total=${#repos[@]}
    local public=0
    local private=0
    
    for repo_info in "${repos[@]}"; do
        IFS='|' read -r repo_name full_name is_private clone_url <<< "$repo_info"
        if [ "$is_private" = "true" ]; then
            ((private++))
        else
            ((public++))
        fi
    done
    
    echo "$total|$public|$private"
}

# Function to print repository summary
print_repo_summary() {
    local title="$1"
    shift
    local repos=("$@")
    local stats
    stats=$(get_repo_stats "${repos[@]}")
    IFS='|' read -r total public private <<< "$stats"
    
    echo ""
    echo "📊 $title"
    echo "=================================================="
    echo "🔓 Public repositories:  $public"
    echo "🔒 Private repositories: $private"
    echo "📦 Total repositories:   $total"
    echo "=================================================="
    
    echo "$total|$public|$private"
}

# Function to validate GitHub token
validate_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        echo "⚠️  No GitHub token provided - using unauthenticated requests (60 requests/hour limit)"
        return 1
    fi
    
    echo "🔐 Validating GitHub token..."
    
    # Test token with user endpoint
    local response
    response=$(curl -s -H "Authorization: token $token" https://api.github.com/user 2>/dev/null)
    
    if echo "$response" | grep -q '"login"'; then
        local username
        username=$(echo "$response" | grep -o '"login": "[^"]*' | cut -d'"' -f4)
        echo "✅ Token is valid - authenticated as: $username"
        
        # Check rate limit
        local rate_response
        rate_response=$(curl -s -H "Authorization: token $token" https://api.github.com/rate_limit 2>/dev/null)
        if echo "$rate_response" | grep -q '"remaining"'; then
            local remaining limit
            remaining=$(echo "$rate_response" | grep -o '"remaining": [0-9]*' | cut -d' ' -f2)
            limit=$(echo "$rate_response" | grep -o '"limit": [0-9]*' | cut -d' ' -f2)
            echo "📊 API Rate limit: $remaining/$limit requests remaining"
        fi
        
        return 0
    elif echo "$response" | grep -q '"message": "Bad credentials"'; then
        echo "❌ Token is invalid or expired"
        echo "   Response: Bad credentials"
        return 1
    else
        echo "❌ Token validation failed"
        echo "   Response: $response" | head -c 100
        return 1
    fi
}

# Function to get repositories with full info
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
        response=$(eval curl -s -w "HTTPSTATUS:%{http_code}" $headers "$url" 2>/dev/null)
        
        local http_code
        http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
        local body
        body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
        
        case "$http_code" in
            404)
                echo "❌ Organization '$org' not found" >&2
                if [ -z "$GITHUB_TOKEN" ]; then
                    echo "   💡 Try with a valid GitHub token if this is a private organization" >&2
                fi
                return 1
                ;;
            401)
                echo "❌ Authentication failed" >&2
                echo "   💡 Check if your GitHub token is valid and has the right permissions" >&2
                return 1
                ;;
            403)
                echo "❌ Access forbidden (403)" >&2
                if echo "$body" | grep -q -i "rate limit"; then
                    echo "   💡 API rate limit exceeded. Try again later or use a valid GitHub token" >&2
                else
                    echo "   💡 Token may not have permission to access this organization" >&2
                fi
                return 1
                ;;
            200)
                # Success - continue processing
                ;;
            *)
                echo "❌ API error: HTTP $http_code" >&2
                echo "   Response: $(echo "$body" | head -c 100)" >&2
                return 1
                ;;
        esac
        
        # Extract repo info using jq if available, otherwise use grep
        local repos_info
        if command -v jq &> /dev/null; then
            repos_info=$(echo "$body" | jq -r '.[] | "\(.name)|\(.full_name)|\(.private)|\(.clone_url)"' 2>/dev/null)
        else
            # Fallback to grep parsing (less reliable)
            repos_info=$(echo "$body" | grep -E '"(name|full_name|private|clone_url)"' | grep -v '"license":' | paste - - - -)
        fi
        
        if [ -z "$repos_info" ]; then
            break
        fi
        
        while IFS= read -r repo_line; do
            if [ -n "$repo_line" ]; then
                if command -v jq &> /dev/null; then
                    # jq output format: name|full_name|private|clone_url
                    all_repos+=("$repo_line")
                else
                    # grep parsing fallback
                    local name full_name is_private clone_url
                    name=$(echo "$repo_line" | grep -o '"name": "[^"]*' | head -1 | cut -d'"' -f4)
                    full_name=$(echo "$repo_line" | grep -o '"full_name": "[^"]*' | cut -d'"' -f4)
                    is_private=$(echo "$repo_line" | grep -o '"private": [^,]*' | cut -d' ' -f2 | tr -d ',')
                    clone_url=$(echo "$repo_line" | grep -o '"clone_url": "[^"]*' | cut -d'"' -f4)
                    
                    if [ -n "$name" ] && [ -n "$full_name" ] && [ -n "$clone_url" ]; then
                        all_repos+=("$name|$full_name|$is_private|$clone_url")
                    fi
                fi
            fi
        done <<< "$repos_info"
        
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
        local repo_info="${repos[$i]}"
        IFS='|' read -r repo_name full_name is_private clone_url <<< "$repo_info"
        local num=$((i + 1))
        
        # Determine clone URL and privacy indicator
        local actual_clone_url="$clone_url"
        local privacy_indicator="🔓"
        
        if [ "$is_private" = "true" ]; then
            privacy_indicator="🔒"
            if [ -n "$GITHUB_TOKEN" ]; then
                actual_clone_url="https://${GITHUB_TOKEN}@github.com/${full_name}.git"
            fi
        elif [ -n "$GITHUB_TOKEN" ]; then
            # Use authenticated URL for all repos when token is available for better reliability
            actual_clone_url="https://${GITHUB_TOKEN}@github.com/${full_name}.git"
        fi
        
        printf "[%d/%d] Cloning %s %s... " "$num" "${#repos[@]}" "$privacy_indicator" "$repo_name"
        
        local clone_output
        clone_output=$(git clone "$actual_clone_url" "$MASTER_FOLDER/$repo_name" 2>&1)
        
        if [ $? -eq 0 ]; then
            echo "✅"
            echo "✅ $privacy_indicator $repo_name" >> "$MASTER_FOLDER/clone_summary.txt"
            ((successful++))
        else
            echo "❌"
            local error_msg=$(echo "$clone_output" | head -1 | cut -c1-50)
            echo "   Error: $error_msg"
            echo "❌ $privacy_indicator $repo_name (FAILED: $error_msg)" >> "$MASTER_FOLDER/clone_summary.txt"
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
    
    # Validate token first
    if ! validate_token "$GITHUB_TOKEN" && [ -n "$GITHUB_TOKEN" ]; then
        echo "⚠️  Continuing with invalid token - some operations may fail"
    fi
    
    # Get repositories from the organization first
    echo "🔍 Fetching repositories for $ORG_NAME..."
    local repo_urls
    repo_urls=$(get_repos "$ORG_NAME")
    
    if [ -z "$repo_urls" ]; then
        echo "❌ No repositories found in organization"
        exit 1
    fi
    
    # Convert to array
    local repos_array=()
    while IFS= read -r line; do
        [ -n "$line" ] && repos_array+=("$line")
    done <<< "$repo_urls"
    
    # Print repository statistics and update summary file
    local stats
    stats=$(print_repo_summary "Organization: $ORG_NAME" "${repos_array[@]}")
    IFS='|' read -r org_total org_public org_private <<< "$stats"
    
    echo "REPOSITORY STATISTICS:" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "🔓 Public repositories:  $org_public" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "🔒 Private repositories: $org_private" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "📦 Total repositories:   $org_total" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
    
    # Check if org folder already exists with repos
    if [ -d "$MASTER_FOLDER" ] && [ "$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)" -gt 0 ]; then
        echo "📂 Folder $MASTER_FOLDER already exists with repositories."
        
        # Get list of existing repo names
        local existing_repos=()
        for repo_dir in "$MASTER_FOLDER"/*; do
            if [ -d "$repo_dir/.git" ]; then
                existing_repos+=($(basename "$repo_dir"))
            fi
        done
        
        # Find missing repositories that need to be cloned
        local missing_repos=()
        for repo_info in "${repos_array[@]}"; do
            IFS='|' read -r repo_name full_name is_private clone_url <<< "$repo_info"
            local found=false
            for existing_repo in "${existing_repos[@]}"; do
                if [ "$repo_name" = "$existing_repo" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                missing_repos+=("$repo_info")
            fi
        done
        
        if [ ${#missing_repos[@]} -gt 0 ]; then
            echo "🆕 Found ${#missing_repos[@]} new repositories to clone:"
            local missing_stats
            missing_stats=$(get_repo_stats "${missing_repos[@]}")
            IFS='|' read -r missing_total missing_public missing_private <<< "$missing_stats"
            echo "   🔓 Public: $missing_public, 🔒 Private: $missing_private"
            
            for repo_info in "${missing_repos[@]}"; do
                IFS='|' read -r repo_name full_name is_private clone_url <<< "$repo_info"
                local privacy_indicator="🔓"
                if [ "$is_private" = "true" ]; then
                    privacy_indicator="🔒"
                fi
                echo "   $privacy_indicator $repo_name"
            done
            
            # Clone missing repositories
            clone_repos "${missing_repos[@]}"
        else
            echo "✅ All organization repositories are already cloned"
        fi
        
        # Sync all existing repositories
        echo ""
        echo "🔄 Syncing existing repositories..."
        sync_repos "$MASTER_FOLDER"
        
        # Final summary
        local total_repos=${#repos_array[@]}
        local cloned_repos=$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)
        echo ""
        echo "🎉 Final Status:"
        echo "📁 Location: $(pwd)/$MASTER_FOLDER"
        echo "📦 Local repositories: $cloned_repos/$total_repos"
        echo "🔓 Public: $public | 🔒 Private: $private"
        
        # Update summary file with final status
        echo "" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "FINAL STATUS:" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "� Local repositories: $cloned_repos/$total_repos" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "🔓 Public: $public | 🔒 Private: $private" >> "$MASTER_FOLDER/clone_summary.txt"
        echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
        return 0
    fi
    
    # Fresh clone - no existing repos
    print_repo_summary "Cloning All Repositories" "${repos_array[@]}"
    clone_repos "${repos_array[@]}"
    
    # Final summary for fresh clone
    local cloned_repos=$(find "$MASTER_FOLDER" -maxdepth 1 -type d -name "*" | grep -v "^$MASTER_FOLDER$" | wc -l)
    echo ""
    echo "🎉 All repositories cloned!"
    echo "📁 Location: $(pwd)/$MASTER_FOLDER"
    echo "📦 Cloned: $cloned_repos/$total repositories"
    echo "🔓 Public: $public | 🔒 Private: $private"
    
    # Update summary file with final status
    echo "" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "FINAL STATUS:" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "📦 Cloned: $cloned_repos/$total repositories" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "🔓 Public: $public | 🔒 Private: $private" >> "$MASTER_FOLDER/clone_summary.txt"
    echo "========================================" >> "$MASTER_FOLDER/clone_summary.txt"
}

main "$@"