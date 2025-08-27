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
            return []
        elif response.status_code != 200:
            print(f"❌ API error: {response.status_code}")
            return []
        
        page_repos = response.json()
        if not page_repos:
            break
            
        repos.extend(page_repos)
        page += 1
    
    print(f"✅ Found {len(repos)} repositories")
    return repos

def clone_repositories(repos, master_folder):
    """Clone all repositories into the master folder"""
    successful = 0
    failed = 0
    
    print(f"\n🚀 Cloning {len(repos)} repositories into {master_folder}")
    
    for i, repo in enumerate(repos, 1):
        repo_name = repo['name']
        clone_url = repo['clone_url']
        repo_path = master_folder / repo_name
        
        print(f"[{i}/{len(repos)}] Cloning {repo_name}...", end=" ")
        
        try:
            result = subprocess.run(
                ["git", "clone", clone_url, str(repo_path)],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            if result.returncode == 0:
                print("✅")
                successful += 1
            else:
                print("❌")
                failed += 1
                
        except Exception:
            print("❌")
            failed += 1
    
    print(f"\n📊 Summary: {successful} successful, {failed} failed")
    return successful, failed

def main():
    org_name = sys.argv[1] if len(sys.argv) > 1 else "DeltaE"
    token = os.getenv('GITHUB_TOKEN')

    # Use MASTER_FOLDER from environment/config, default to 'cloned_repos'
    master_folder_base = os.getenv('MASTER_FOLDER', 'cloned_repos')
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    master_folder = Path(f"{master_folder_base}_{timestamp}")
    master_folder.mkdir(exist_ok=True)
    print(f"📁 Created master folder: {master_folder}")

    # Get and clone repositories
    repos = get_repositories(org_name, token)
    if repos:
        clone_repositories(repos, master_folder)
        print(f"\n🎉 All repositories cloned in: {master_folder.absolute()}")
    else:
        print("❌ No repositories to clone")

if __name__ == "__main__":
    main()