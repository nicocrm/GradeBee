import json
import sys
import os

def update_appwrite_project(source, target):
    # Define file paths
    source_file_path = f'envs/{source}/appwrite.json'
    target_file_path = f'envs/{target}/appwrite.json'

    # Check if source and target files exist
    if not os.path.exists(source_file_path):
        print(f"Source file {source_file_path} does not exist.")
        return
    if not os.path.exists(target_file_path):
        print(f"Target file {target_file_path} does not exist.")
        return

    # Read target file to get projectId and projectName
    with open(target_file_path, 'r') as target_file:
        target_data = json.load(target_file)
        target_project_id = target_data.get('projectId')
        target_project_name = target_data.get('projectName')

    # Read source file
    with open(source_file_path, 'r') as source_file:
        source_data = json.load(source_file)

    # Update source data with target projectId and projectName
    source_data['projectId'] = target_project_id
    source_data['projectName'] = target_project_name

    # Write updated data back to target file
    with open(target_file_path, 'w') as target_file:
        json.dump(source_data, target_file, indent=4)

    print(f"Updated {target_file_path} with projectId: {target_project_id} and projectName: {target_project_name}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python update_appwrite_project.py <source> <target>")
    else:
        source_env = sys.argv[1]
        target_env = sys.argv[2]
        update_appwrite_project(source_env, target_env) 