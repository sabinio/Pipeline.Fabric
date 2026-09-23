# import from fabric_cicd 
from fabric_cicd import FabricWorkspace, publish_all_items, unpublish_all_orphan_items, get_changed_items, append_feature_flag, change_log_level
from azure.identity import DefaultAzureCredential
import argparse
import os

append_feature_flag("enable_shortcut_publish")
append_feature_flag("enable_experimental_features")
append_feature_flag("enable_environment_variable_replacement")
                     
parser = argparse.ArgumentParser(description='Process some variables.')
parser.add_argument('--WorkspaceId', type=str)
parser.add_argument('--Environment', type=str)
parser.add_argument('--RepositoryDirectory', type=str)
parser.add_argument('--ItemsInScope', type=str)
parser.add_argument('--ParameterFile', type=str, required=False)
parser.add_argument('--OnlyChanged', type=lambda x: x.lower() == 'true', required=False, default=False)
parser.add_argument('--Debug', type=lambda x: x.lower() == 'true', required=False, default=False)
parser.add_argument('--BulkDeploy', type=lambda x: x.lower() == 'true', required=False, default=False)
args = parser.parse_args()

if args.Debug:
    change_log_level()

# Convert item_type_in_scope into a list
allitems = args.ItemsInScope
item_type_in_scope=allitems.split(",")
print(item_type_in_scope)

credential = DefaultAzureCredential()

# Initialize the FabricWorkspace object with the required parameters
if args.ParameterFile:
    target_workspace = FabricWorkspace(
        workspace_id= args.WorkspaceId,
        environment=args.Environment,
        repository_directory=args.RepositoryDirectory,
        item_type_in_scope=item_type_in_scope,
        parameter_file_path=args.ParameterFile,
        token_credential=credential
    )
else:
    target_workspace = FabricWorkspace(
        workspace_id= args.WorkspaceId,
        environment=args.Environment,
        repository_directory=args.RepositoryDirectory,
        item_type_in_scope=item_type_in_scope,   
        token_credential=credential,
    )


# # # Publish all items defined in item_type_in_scope
if (args.BulkDeploy == True):
    append_feature_flag("enable_bulk_deploy")
    print("Bulk Deploy configured.")
else:
    print("Bulk Deploy not configured.")

if (args.OnlyChanged == True):
    print("Only publishing changed items")
    append_feature_flag("enable_experimental_features")
    append_feature_flag("enable_items_to_include")

    changed = get_changed_items(target_workspace.repository_directory)

    publish_all_items(target_workspace,items_to_include=changed)
else:
    print("Publishing all items")
    publish_all_items(target_workspace)

# # # Unpublish all items defined in item_type_in_scope not found in repository
unpublish_all_orphan_items(target_workspace)
