import argparse
import sys
import traceback
from git import Repo, GitCommandError

def main():
    # Set up argument parsing
    parser = argparse.ArgumentParser(description='Commit and tag in a Git repository.')
    parser.add_argument('tag', help='The tag name to create.')
    parser.add_argument('commit_message', help='The commit message for the new commit.')
    args = parser.parse_args()


    try:
        # Open the repository
        try:
            repo = Repo('.')
            print('Repository opened successfully.')
        except Exception as e:
            print('Error: Could not open the repository.')
            print(f'Detailed error: {e}')
            sys.exit(1)

        # Stage all changes
        try:
            repo.git.add(A=True)  # Stage all changes
            print('All changes staged successfully.')
        except GitCommandError as e:
            print('Error: Could not stage changes.')
            print(f'Detailed error: {e}')
            sys.exit(1)

        # Create a new commit
        try:
            commit_message = args.commit_message
            if repo.is_dirty(index=True, working_tree=True, untracked_files=True):
                new_commit = repo.index.commit(commit_message)
                print(f'New commit created: {new_commit.hexsha}')
            else:
                # If there are no changes, make an empty commit
                new_commit = repo.git.commit(allow_empty=True, message=commit_message)
                print('No changes detected. Created an empty commit.')
        except GitCommandError as e:
            print('Error: Could not create the commit.')
            print(f'Detailed error: {e}')
            sys.exit(1)

        # Tag the new commit
        try:
            tag_name = args.tag
            tag_message = tag_name

            if tag_name in repo.tags:
                print(f'Tag {tag_name} already exists.')
                sys.exit(1)

            new_tag = repo.create_tag(tag_name, new_commit, message=tag_message)
            print(f'Tag {tag_name} created at {new_tag.commit.hexsha}.')
        except GitCommandError as e:
            print('Error: Could not create the tag.')
            print(f'Detailed error: {e}')
            sys.exit(1)
        except Exception as e:
            print('An unexpected error occurred while creating the tag:')
            print(f'Detailed error: {e}')
            sys.exit(1)

        # Push the commit and the tag
        try:
            origin = repo.remote(name='origin')
            origin.push()
            origin.push(tags=True)
            print(f'Commit and tag {tag_name} pushed to remote.')
        except GitCommandError as e:
            if 'Could not read from remote repository' in str(e):
                print('Error: Could not read from remote repository. Please check your remote URL and authentication settings.')
            else:
                print('Error: Could not push the commit and tag to the remote repository.')
                print(f'Detailed error: {e}')
            sys.exit(1)
        except Exception as e:
            print('An unexpected error occurred while pushing the commit and tag:')
            print(f'Detailed error: {e}')
            sys.exit(1)

    except Exception as e:
        # Print detailed traceback for debugging
        print('An unexpected error occurred:')
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
