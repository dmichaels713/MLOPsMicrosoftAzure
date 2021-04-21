param keyVaultAccessPolicyTargetObjectId string

var location = resourceGroup().location
var tenantId = subscription().tenantId

var resourceUniqueSuffix = uniqueString(resourceGroup().id)

var keyVaultName = 'keyvault${resourceUniqueSuffix}'
var storageAccountName = 'storage${resourceUniqueSuffix}'
var mlWorkspaceName = 'mlworkspace${resourceUniqueSuffix}'
var computeInstanceName = 'mlci${resourceUniqueSuffix}'
var mlClusterName = 'cl${resourceUniqueSuffix}'
var appInsightsName = 'appinisghts${resourceUniqueSuffix}'
var containerRegistryName = 'containerregistry${resourceUniqueSuffix}'

resource vault 'Microsoft.KeyVault/vaults@2020-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enabledForDeployment: false
    enableSoftDelete: true
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: keyVaultAccessPolicyTargetObjectId
        permissions: {
          keys: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
          certificates: [
            'get'
            'list'
            'update'
            'create'
            'import'
            'delete'
            'recover'
            'backup'
            'restore'
            'managecontacts'
            'manageissuers'
            'getissuers'
            'listissuers'
            'setissuers'
            'deleteissuers'
          ]
        }
      }
    ]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource storageCors 'Microsoft.Storage/storageAccounts/blobServices@2020-08-01-preview' = {
  name: '${storage.name}/default'
  properties: {
    cors: {
      corsRules: [
        {
          maxAgeInSeconds: 1800
          allowedOrigins: [
            'https://mlworkspace.azure.ai'
            'https://ml.azure.com'
            'https://*.ml.azure.com'
            'https://mlworkspace.azureml-test.net'
          ]
          allowedMethods: [
            'GET'
            'HEAD'
          ]
          exposedHeaders: [
            '*'
          ]
          allowedHeaders: [
            '*'
          ]          
        }
      ]
    }
  }
}

resource mlMetricsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storage.name}/default/azureml-metrics'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  } 
}

resource mlRevisionsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storage.name}/default/revisions'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  } 
}

resource mlSnapshotsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storage.name}/default/snapshots'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  } 
}

resource mlSnapshotZipsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storage.name}/default/snapshotzips'
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
    publicAccess: 'None'
  } 
}

// TODO:  Need containers and shares that have GUID in share/container name, not sure how those map
// to aml ws

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'ApplicationInsights'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
     adminUserEnabled: true
     policies: {
       quarantinePolicy: {
         status: 'disabled'
       }
       trustPolicy: {
         type: 'Notary'
         status: 'disabled'
       }
       retentionPolicy: {
         days: 7
         status: 'disabled'
       }
     }
     encryption: {
       status: 'disabled'
     }
     dataEndpointEnabled: false
     publicNetworkAccess: 'Enabled'
     networkRuleBypassOptions: 'AzureServices'
     zoneRedundancy: 'Disabled'
  }
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2020-06-01' = {
  name: mlWorkspaceName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: mlWorkspaceName
    storageAccount: storage.id
    containerRegistry: containerRegistry.id
    keyVault: vault.id
    applicationInsights: appInsights.id
    hbiWorkspace: false
    allowPublicAccessWhenBehindVnet: false
    discoveryUrl: 'https://${location}.experiments.azureml.net/discovery'
  }
}

resource mlCompute 'Microsoft.MachineLearningServices/workspaces/computes@2021-01-01' = {
  name: '${mlWorkspace.name}/${computeInstanceName}'
  location: location
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    properties: {
      vmSize: 'STANDARD_DS11_V2'
      sshSettings: {
        sshPublicAccess: 'Disabled'        
      }
      applicationSharingPolicy: 'Shared'
    }
  }
}

resource mlCluster 'Microsoft.MachineLearningServices/workspaces/computes@2021-01-01' = {
  name: '${mlWorkspace.name}/${mlClusterName}'
  location: location
  identity: {
    type: 'None'
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    properties: {
      vmSize: 'STANDARD_DS11_V2'
      vmPriority: 'Dedicated'
      scaleSettings: {
        maxNodeCount: 8
        minNodeCount: 0
        nodeIdleTimeBeforeScaleDown: 'PT2M'
      }
      remoteLoginPortPublicAccess: 'Enabled'
      osType: 'Linux'
      isolatedNetwork: false
    }
  }
}
