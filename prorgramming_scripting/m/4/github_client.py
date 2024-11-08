import requests
import logging
from requests.exceptions import HTTPError

# Set up logging configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GitHubClient:
    def __init__(self, token: str, organization: str):
        self.token = token
        self.organization = organization
        self.base_url = "https://api.github.com"

    def _headers(self):
        return {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json"
        }

    def create_repository(self, repo_name: str, description: str = "", is_private: bool = False):
        # Check if the repository already exists
        check_url = f"{self.base_url}/repos/{self.organization}/{repo_name}"
        try:
            response = requests.get(check_url, headers=self._headers())
            response.raise_for_status()
            logger.info(f"Repository '{repo_name}' already exists.")
            return response.json()
        except HTTPError as e:
            if e.response.status_code == 404:
                logger.info(f"Repository '{repo_name}' does not exist. Creating it now.")
            else:
                raise e

        # Repository does not exist, proceed with creation
        url = f"{self.base_url}/orgs/{self.organization}/repos"
        data = {
            "name": repo_name,
            "description": description,
            "private": is_private,
            "auto_init": True  # Creates an initial commit with a README
        }
        response = requests.post(url, headers=self._headers(), json=data)
        response.raise_for_status()
        logger.info(f"Repository '{repo_name}' created successfully.")
        return response.json()

    def create_branch(self, repo_name: str, source_branch_name: str, target_branch_name: str):
        # Check if the target branch already exists
        target_url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/ref/heads/{target_branch_name}"
        try:
            response = requests.get(target_url, headers=self._headers())
            response.raise_for_status()
            logger.info(f"Branch '{target_branch_name}' already exists.")
            return response.json()  # Exit if branch already exists
        except HTTPError as e:
            if e.response.status_code == 404:
                logger.info(f"Target branch '{target_branch_name}' does not exist, proceeding to create it.")
            else:
                raise e

        # Check if the source branch exists (i.e., the repository is not empty)
        source_url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/ref/heads/{source_branch_name}"
        try:
            response = requests.get(source_url, headers=self._headers())
            response.raise_for_status()
            source_sha = response.json()["object"]["sha"]
        except HTTPError as e:
            logger.error(f"Source branch '{source_branch_name}' does not exist.")
            raise e

        # Create the new branch with the SHA of the source branch or initial commit
        create_branch_url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/refs"
        data = {
            "ref": f"refs/heads/{target_branch_name}",
            "sha": source_sha
        }
        response = requests.post(create_branch_url, headers=self._headers(), json=data)
        response.raise_for_status()
        logger.info(f"Branch '{target_branch_name}' created successfully in '{repo_name}'.")
        return response.json()

    def add_tag(self, repo_name: str, branch_name: str, tag_message: str, tag_name: str):
        url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/ref/heads/{branch_name}"
        response = requests.get(url, headers=self._headers())
        response.raise_for_status()
        
        branch_sha = response.json()["object"]["sha"]
        create_tag_url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/tags"
        data = {
            "tag": tag_name,
            "message": tag_message,
            "object": branch_sha,
            "type": "commit"
        }
        response = requests.post(create_tag_url, headers=self._headers(), json=data)
        response.raise_for_status()
        
        tag_sha = response.json()["sha"]
        ref_url = f"{self.base_url}/repos/{self.organization}/{repo_name}/git/refs"
        ref_data = {
            "ref": f"refs/tags/{tag_name}",
            "sha": tag_sha
        }
        try:
            response = requests.post(ref_url, headers=self._headers(), json=ref_data)
            response.raise_for_status()
            logger.info(f"Tag '{tag_name}' added to branch '{branch_name}'.")
            return response.json()
        except HTTPError as e:
            if e.response.status_code == 422:
                logger.warning(f"Tag '{tag_name}' already exists in '{repo_name}'.")
                return e.response.json()
            else:
                raise e
