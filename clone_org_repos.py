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

def clone_repositories(repos, master_folder):
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
                with open(summary_file, 'a') as f:
                    f.write(f"✅ {repo_name}\n")
                successful += 1
            else:
                print("❌")
                with open(summary_file, 'a') as f:
                    f.write(f"❌ {repo_name} (FAILED)\n")
                failed += 1
                
        except Exception:
            print("❌")
            with open(summary_file, 'a') as f:
                f.write(f"❌ {repo_name} (FAILED)\n")
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
        clone_repositories(repos, master_folder)
        print(f"\n🎉 All repositories cloned in: {master_folder.absolute()}")
    else:
        print("❌ No repositories to clone")

if __name__ == "__main__":
    main()