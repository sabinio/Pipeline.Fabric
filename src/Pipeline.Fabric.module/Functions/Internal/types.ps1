# Fabric item types.
# Source: https://learn.microsoft.com/en-us/rest/api/fabric/core/items/list-items#itemtype
# Note: the API states "Additional item types may be added over time."
$script:ItemTypes = @(
    'Dashboard'                       # PowerBI dashboard.
    'Report'                          # PowerBI report.
    'SemanticModel'                   # PowerBI semantic model.
    'PaginatedReport'                 # PowerBI paginated report.
    'Datamart'                        # PowerBI datamart.
    'Lakehouse'                       # A lakehouse.
    'Eventhouse'                      # An eventhouse.
    'Environment'                     # An environment.
    'KQLDatabase'                     # A KQL database.
    'KQLQueryset'                     # A KQL queryset.
    'KQLDashboard'                    # A KQL dashboard.
    'DataPipeline'                    # A data pipeline.
    'Notebook'                        # A notebook.
    'SparkJobDefinition'              # A spark job definition.
    'MLExperiment'                    # A machine learning experiment.
    'MLModel'                         # A machine learning model.
    'Warehouse'                       # A warehouse.
    'Eventstream'                     # An eventstream.
    'SQLEndpoint'                     # An SQL endpoint.
    'MirroredWarehouse'               # A mirrored warehouse.
    'MirroredDatabase'                # A mirrored database.
    'Reflex'                          # A Reflex.
    'GraphQLApi'                      # An API for GraphQL item.
    'MountedDataFactory'              # A MountedDataFactory.
    'SQLDatabase'                     # A SQLDatabase.
    'CopyJob'                         # A Copy job.
    'VariableLibrary'                 # A VariableLibrary.
    'Dataflow'                        # A Dataflow.
    'ApacheAirflowJob'                # An ApacheAirflowJob.
    'WarehouseSnapshot'               # A Warehouse snapshot.
    'DigitalTwinBuilder'              # A DigitalTwinBuilder.
    'DigitalTwinBuilderFlow'          # A Digital Twin Builder Flow.
    'MirroredAzureDatabricksCatalog'  # A mirrored azure databricks catalog.
    'Map'                             # A Map.
    'AnomalyDetector'                 # An Anomaly Detector.
    'UserDataFunction'                # A User Data Function.
    'GraphModel'                      # A GraphModel.
    'GraphQuerySet'                   # A Graph QuerySet.
    'SnowflakeDatabase'               # A Snowflake Database (Iceberg tables from a Snowflake account).
    'OperationsAgent'                 # An OperationsAgent.
    'CosmosDBDatabase'                # A Cosmos DB Database.
    'Ontology'                        # An Ontology.
    'EventSchemaSet'                  # An EventSchemaSet.
    'DataAgent'                       # A DataAgent.
    'MirroredCatalog'                 # A MirroredCatalog.
    'AppBackend'                      # An AppBackend.
    'OrgApp'                          # An Org App.
    'OrgAppAudience'                  # An Org App Audience.
    'DataBuildToolJob'               # A DataBuildToolJob.
    'AzureDatabricksStorage'          # A OneLake-backed storage item for Azure Databricks.
)
