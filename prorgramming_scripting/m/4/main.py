# main.py
import os
from dotenv import load_dotenv
from github_client import GitHubClient

load_dotenv()

def main():
    
    # Instantiate GitHub client
    client = GitHubClient(token=os.getenv("GITHUB_TOKEN"), organization=os.getenv("GITHUB_ORGANIZATION"))

    # Define repository details
    repo_name = "example-repo"
    description = "Repository created via script"
    branch_name = "develop"
    tag_name = "v0.1.2"
    tag_message = "Initial release#2"

    # Step 1: Create Repository
    client.create_repository(repo_name=repo_name, description=description)
    
    # Step 2: Create New Branch
    client.create_branch(repo_name=repo_name, source_branch_name='main', target_branch_name=branch_name)
    
    # Step 3: Add Tag
    client.add_tag(repo_name=repo_name, branch_name=branch_name, tag_message=tag_message, tag_name=tag_name)

if __name__ == "__main__":
    main()
