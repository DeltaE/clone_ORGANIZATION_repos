#!/usr/bin/env python3
"""
Simple script to clone all repositories from a GitHub organization
Creates a timestamped folder with all repos inside
Usage: python3 clone_org_repos.py [organization_name]
"""

import os
import sys
import subprocess
import requests
from datetime import datetime
from pathlib import Path

def load_config():
    """Load configuration from config.env file"""
    config_file = "config.env"
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Only set if not already in environment
                    if key not in os.environ:
                        os.environ[key] = value

def get_repo_statistics(repos):
    """Calculate repository statistics"""
    total = len(repos)
    private = sum(1 for repo in repos if repo.get('private', False))
    public = total - private
    return {
        'total': total,
        'public': public,
        'private': private
    }

def print_repo_summary(repos, title="Repository Summary"):
    """Print a formatted summary of repositories"""
    stats = get_repo_statistics(repos)
    print(f"\n📊 {title}")
    print("=" * 50)
    print(f"🔓 Public repositories:  {stats['public']}")
    print(f"🔒 Private repositories: {stats['private']}")
    print(f"📦 Total repositories:   {stats['total']}")
    print("=" * 50)
    return stats

def validate_token(token):
    """Validate GitHub token and show rate limit info"""
    if not token:
        print("⚠️  No GitHub token provided - using unauthenticated requests (60 requests/hour limit)")
        return False
    
    print(f"🔐 Validating GitHub token...")
    headers = {"Authorization": f"token {token}"}
    
    try:
        # Test token with user endpoint
        response = requests.get("https://api.github.com/user", headers=headers)
        
        if response.status_code == 200:
            user_data = response.json()
            username = user_data.get('login', 'Unknown')
            print(f"✅ Token is valid - authenticated as: {username}")
            
            # Check rate limit
            rate_response = requests.get("https://api.github.com/rate_limit", headers=headers)
            if rate_response.status_code == 200:
                rate_data = rate_response.json()
                core_limit = rate_data['resources']['core']
                remaining = core_limit['remaining']
                limit = core_limit['limit']
                print(f"📊 API Rate limit: {remaining}/{limit} requests remaining")
            
            return True
        elif response.status_code == 401:
            print(f"❌ Token is invalid or expired")
            print(f"   Response: {response.json().get('message', 'Unknown error')}")
            return False
        else:
            print(f"❌ Token validation failed with status: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error validating token: {e}")
        return False

def get_repositories(org_name, token=None):
    """Fetch all repositories from the organization"""
    repos = []
    page = 1
    headers = {"Authorization": f"token {token}"} if token else {}
    
    print(f"🔍 Fetching repositories for {org_name}...")
    
    while True:
        url = f"https://api.github.com/orgs/{org_name}/repos"
        params = {"page": page, "per_page": 100}
        
        response = requests.get(url, headers=headers, params=params)
        
        if response.status_code == 404:
            print(f"❌ Organization '{org_name}' not found")
            if not token:
                print("   💡 Try with a valid GitHub token if this is a private organization")
            return []
        elif response.status_code == 401:
            print(f"❌ Authentication failed")
            print("   💡 Check if your GitHub token is valid and has the right permissions")
            return []
        elif response.status_code == 403:
            print(f"❌ Access forbidden (403)")
            if 'rate limit' in response.text.lower():
                print("   💡 API rate limit exceeded. Try again later or use a valid GitHub token")
            else:
                print("   💡 Token may not have permission to access this organization")
            return []
        elif response.status_code != 200:
            print(f"❌ API error: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return []
        
        page_repos = response.json()
        if not page_repos:
            break
            
        repos.extend(page_repos)
        page += 1
    
    print(f"✅ Found {len(repos)} repositories")
    return repos

def sync_repositories(master_folder):
    """Sync existing repositories by pulling latest changes"""
    successful = 0
    failed = 0
    
    print(f"\n🔄 Syncing existing repositories in {master_folder}")
    
    # Update summary file for sync operation
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    summary_file = master_folder / "clone_summary.txt"
    with open(summary_file, 'a') as f:
        f.write(f"\nSYNC OPERATION - {timestamp}\n")
        f.write("----------------------------------------\n")
    
    for repo_dir in master_folder.iterdir():
        if repo_dir.is_dir() and (repo_dir / ".git").exists():
            repo_name = repo_dir.name
            print(f"Syncing {repo_name}...", end=" ")
            
            try:
                # Try git fetch and pull
                fetch_result = subprocess.run(
                    ["git", "fetch", "--all"],
                    cwd=repo_dir,
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                pull_result = subprocess.run(
                    ["git", "pull"],
                    cwd=repo_dir,
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                if pull_result.returncode == 0:
                    print("✅")
                    with open(summary_file, 'a') as f:
                        f.write(f"✅ {repo_name} (synced)\n")
                    successful += 1
                elif fetch_result.returncode == 0:
                    print("🔄 (fetched only)")
                    with open(summary_file, 'a') as f:
                        f.write(f"🔄 {repo_name} (fetched only)\n")
                    successful += 1
                else:
                    print("❌")
                    with open(summary_file, 'a') as f:
                        f.write(f"❌ {repo_name} (sync failed)\n")
                    failed += 1
                    
            except Exception:
                print("❌")
                with open(summary_file, 'a') as f:
                    f.write(f"❌ {repo_name} (sync failed)\n")
                failed += 1
    
    with open(summary_file, 'a') as f:
        f.write("----------------------------------------\n")
        f.write(f"SYNC SUMMARY: {successful} successful, {failed} failed\n")
        f.write("========================================\n")
    
    if successful > 0 or failed > 0:
        print(f"\n📊 Sync Summary: {successful} successful, {failed} failed")
    else:
        print(f"\n📊 No repositories found to sync")
    return successful, failed

def clone_repositories(repos, master_folder, token=None):
    """Clone all repositories into the master folder"""
    successful = 0
    failed = 0
    
    print(f"\n🚀 Cloning {len(repos)} repositories into {master_folder}")
    
    # Add cloned repos header to summary
    summary_file = master_folder / "clone_summary.txt"
    with open(summary_file, 'a') as f:
        f.write("\nCLONED REPOSITORIES:\n")
        f.write("----------------------------------------\n")
    
    for i, repo in enumerate(repos, 1):
        repo_name = repo['name']
        is_private = repo.get('private', False)
        
        # Use authenticated URL for private repos or when token is available
        if token and (is_private or True):  # Use token for all repos when available
            clone_url = f"https://{token}@github.com/{repo['full_name']}.git"
        else:
            clone_url = repo['clone_url']
        
        repo_path = master_folder / repo_name
        privacy_indicator = "🔒" if is_private else "🔓"
        
        print(f"[{i}/{len(repos)}] Cloning {privacy_indicator} {repo_name}...", end=" ")
        
        try:
            result = subprocess.run(
                ["git", "clone", clone_url, str(repo_path)],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                print("✅")
                with open(summary_file, 'a') as f:
                    f.write(f"✅ {privacy_indicator} {repo_name}\n")
                successful += 1
            else:
                print("❌")
                error_msg = result.stderr.strip() if result.stderr else "Unknown error"
                print(f"   Error: {error_msg[:100]}")
                with open(summary_file, 'a') as f:
                    f.write(f"❌ {privacy_indicator} {repo_name} (FAILED: {error_msg[:50]})\n")
                failed += 1
                
        except Exception as e:
            print("❌")
            print(f"   Error: {str(e)[:100]}")
            with open(summary_file, 'a') as f:
                f.write(f"❌ {privacy_indicator} {repo_name} (FAILED: {str(e)[:50]})\n")
            failed += 1
    
    # Add summary footer
    with open(summary_file, 'a') as f:
        f.write("----------------------------------------\n")
        f.write(f"SUMMARY: {successful} successful, {failed} failed\n")
        f.write("========================================\n")
    
    print(f"\n📊 Summary: {successful} successful, {failed} failed")
    return successful, failed

def main():
    # Load configuration from config.env file
    load_config()
    
    org_name = sys.argv[1] if len(sys.argv) > 1 else os.getenv('ORG_NAME', 'DeltaE')
    token = os.getenv('GITHUB_TOKEN')

    print(f"🔄 Cloning all repositories from organization: {org_name}")
    
    # Validate token first
    token_valid = validate_token(token)
    if not token_valid and token:
        print("⚠️  Continuing with invalid token - some operations may fail")

    # Use MASTER_FOLDER from environment/config, default to 'cloned_repos'
    master_folder_base = os.getenv('MASTER_FOLDER', 'cloned_repos')
    master_folder = Path(f"{master_folder_base}/{org_name}")
    master_folder.mkdir(parents=True, exist_ok=True)
    
    # Create timestamp summary file
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    summary_file = master_folder / "clone_summary.txt"
    with open(summary_file, 'w') as f:
        f.write("========================================\n")
        f.write("CLONE OPERATION SUMMARY\n")
        f.write("========================================\n")
        f.write(f"Organization: {org_name}\n")
        f.write(f"Date/Time: {timestamp}\n")
        f.write("========================================\n")
    
    print(f"📁 Target folder: {master_folder}")
    
    # Get repositories from the organization first
    repos = get_repositories(org_name, token)
    if not repos:
        print("❌ No repositories found in organization")
        return
    
    # Print repository statistics and update summary file
    stats = print_repo_summary(repos, f"Organization: {org_name}")
    with open(summary_file, 'a') as f:
        f.write("REPOSITORY STATISTICS:\n")
        f.write(f"🔓 Public repositories:  {stats['public']}\n")
        f.write(f"🔒 Private repositories: {stats['private']}\n")
        f.write(f"📦 Total repositories:   {stats['total']}\n")
        f.write("========================================\n")
    
    # Check if folder already exists with repos
    existing_repos = [d for d in master_folder.iterdir() if d.is_dir() and (d / ".git").exists()]
    if existing_repos:
        print(f"📂 Folder {master_folder} already exists with repositories.")
        
        # Get list of existing repo names
        existing_repo_names = {d.name for d in existing_repos}
        
        # Find missing repositories that need to be cloned
        missing_repos = [repo for repo in repos if repo['name'] not in existing_repo_names]
        
        if missing_repos:
            print(f"🆕 Found {len(missing_repos)} new repositories to clone:")
            missing_stats = get_repo_statistics(missing_repos)
            print(f"   🔓 Public: {missing_stats['public']}, 🔒 Private: {missing_stats['private']}")
            for repo in missing_repos:
                privacy_indicator = "🔒" if repo.get('private', False) else "🔓"
                print(f"   {privacy_indicator} {repo['name']}")
            
            # Clone missing repositories
            clone_repositories(missing_repos, master_folder, token)
        else:
            print("✅ All organization repositories are already cloned")
        
        # Sync all existing repositories
        print(f"\n🔄 Syncing existing repositories...")
        sync_repositories(master_folder)
        
        # Final summary
        total_repos = len(repos)
        cloned_repos = len([d for d in master_folder.iterdir() if d.is_dir() and (d / ".git").exists()])
        print(f"\n🎉 Final Status:")
        print(f"📁 Location: {master_folder.absolute()}")
        print(f"📦 Local repositories: {cloned_repos}/{total_repos}")
        print(f"🔓 Public: {stats['public']} | 🔒 Private: {stats['private']}")
        
        # Update summary file with final status
        with open(summary_file, 'a') as f:
            f.write(f"\nFINAL STATUS:\n")
            f.write(f"📦 Local repositories: {cloned_repos}/{total_repos}\n")
            f.write(f"🔓 Public: {stats['public']} | 🔒 Private: {stats['private']}\n")
            f.write("========================================\n")
        return

    # Fresh clone - no existing repos
    print_repo_summary(repos, "Cloning All Repositories")
    clone_repositories(repos, master_folder, token)
    
    # Final summary for fresh clone
    cloned_repos = len([d for d in master_folder.iterdir() if d.is_dir() and (d / ".git").exists()])
    print(f"\n🎉 All repositories cloned!")
    print(f"📁 Location: {master_folder.absolute()}")
    print(f"📦 Cloned: {cloned_repos}/{stats['total']} repositories")
    print(f"🔓 Public: {stats['public']} | 🔒 Private: {stats['private']}")
    
    # Update summary file with final status
    with open(summary_file, 'a') as f:
        f.write(f"\nFINAL STATUS:\n")
        f.write(f"📦 Cloned: {cloned_repos}/{stats['total']} repositories\n")
        f.write(f"🔓 Public: {stats['public']} | 🔒 Private: {stats['private']}\n")
        f.write("========================================\n")

if __name__ == "__main__":
    main()