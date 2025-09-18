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
    org_name = sys.argv[1] if len(sys.argv) > 1 else "DeltaE"
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
    
    # Check if folder already exists with repos
    existing_repos = [d for d in master_folder.iterdir() if d.is_dir() and (d / ".git").exists()]
    if existing_repos:
        print(f"� Folder {master_folder} already exists with repositories. Syncing instead of cloning.")
        sync_repositories(master_folder)
        print(f"\n🎉 All repositories synced in: {master_folder.absolute()}")
        return

    # Get and clone repositories
    repos = get_repositories(org_name, token)
    if repos:
        clone_repositories(repos, master_folder, token)
        print(f"\n🎉 All repositories cloned in: {master_folder.absolute()}")
    else:
        print("❌ No repositories to clone")

if __name__ == "__main__":
    main()