---
page_type: sample
languages:
- azdeveloper
- bicep
- xml
products:
- azure-api-management
- azure-api-center
- azure-key-vault
- azure-log-analytics
- azure-monitor
urlFragment: azd-apic-sap
name: Discover your SAP & Azure API Management APIs in one place with Azure API Center
description: Improve the discoverability and governance of all your APIs in one place, with Azure API Center. In this sample we expose SAP APIs directly and Azure API Management APIs connected to an SAP OData backend to API Center, deployed with Azure Developer CLI (azd)
---
<!-- YAML front-matter schema: https://review.learn.microsoft.com/en-us/help/contribute/samples/process/onboarding?branch=main#supported-metadata-fields-for-readmemd -->

[![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=lightgrey&logo=github)](https://codespaces.new/azure-samples/azd-apic-sap)
[![Open in Dev Container](https://img.shields.io/static/v1?style=for-the-badge&label=Dev+Container&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/azure-samples/azd-apic-sap)

<!--
Available as template on:
[![Awesome Badge](https://awesome.re/badge-flat2.svg)](https://aka.ms/awesome-azd)
`azd`
-->

# Discover your SAP & Azure API Management APIs in one place with Azure API Center

Improve the discoverability and governance of all your APIs in one place, with Azure API Center. In this sample we expose SAP APIs directly and Azure API Management APIs connected to an SAP OData backend to API Center, deployed with Azure Developer CLI (`azd`).

This repository provides guidance and tools for organizations looking to implement Azure API Center to improve the discoverability and governance of all APIs in one place. The repository includes a Bicep template for provisioning and deploying the resources, and a sample API implementation that demonstrates how to expose SAP APIs directly and Azure API Management APIs connected to an SAP OData backend to API Center.

> [!TIP]
> Have a look at [this blog post](https://community.sap.com/t5/technology-blogs-by-members/govern-sap-apis-living-in-various-api-management-gateways-in-a-single-place/ba-p/13682483) for more details on the approach.

## Key features ⚙️

- **Infrastructure-as-code**: Bicep templates for provisioning and deploying the resources.
- **API Inventory**: Register all of your organization's APIs for inclusion in a centralized inventory.
- **API Covernance**: Organize and filter APIs and related resources using built-in and custom metadata properties, to help with API governance and discovery by API consumers. Set up linting and analysis to enforce API definition quality.
- **API Discovery**: Enable developers and API program managers to discover APIs via the Azure portal, an API Center portal, and developer tools including a Visual Studio Code extension integrated with GitHub Copilot.
- **SAP Integration**: Expose your SAP backend via Azure API Management or via SAP API Management to Azure API Center.
- **End-to-end sample**: Including dashboards, sample APIs and Developer Portals.

## Architecture 🏛️

![azd-apic-sap](docs/images/arch.png)
Read more: [Architecture in detail](#architecture-in-detail)

## Assets 📦

- Infrastructure-as-code (IaC) Bicep files under the `infra` folder that demonstrate how to provision resources and setup resource tagging for azd.
- A [dev container](https://containers.dev) configuration file under the `.devcontainer` directory that installs infrastructure tooling by default. This can be readily used to create cloud-hosted developer environments such as [GitHub Codespaces](https://aka.ms/codespaces) or a local environment via a [VSCode DevContainer](https://code.visualstudio.com/docs/devcontainers/containers).
- Continuous deployment workflows for CI providers such as GitHub Actions under the `.github` directory, and Azure Pipelines under the `.azdo` directory that work for most use-cases.

## Getting started 🛫

### Prerequisites (steps not that are not automated by AZD)

- [Azure Developer CLI](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- An SAP Integration Suite instance with the [SAP API management capability](https://developers.sap.com/group.cp-apim-code-1.html) activated in your SAP BTP subaccount.
- The [API Management, developer portal](https://help.sap.com/docs/integration-suite/sap-integration-suite/api-access-plan-for-api-business-hub-enterprise) service deployed in your SAP BTP subaccount.
- At least one OData API hosted on an SAP system available.

> [!TIP]
> Consider the SAP BTP terraform provider to automate the provisioning of SAP BTP services for a fully integrated experience. Find more information [here](https://developers.sap.com/tutorials/btp-terraform-get-started.html).

### Preparing your OData API

Arguably the fastest way to interact with an SAP OData API is the SAP Business Accelerator hub. Once signed up you can tryout for instance Business Partner API [here](https://api.sap.com/api/API_BUSINESS_PARTNER/tryout). You'll find the API documentation [here](https://api.sap.com/api/API_BUSINESS_PARTNER/overview).

> [!TIP]
> The SAP Sandbox environment as mentioned above, the SAP_ENDPOINT is [here](https://sandbox.api.sap.com/s4hanacloud/sap/opu/odata/sap/API_BUSINESS_PARTNER). The SAP_APIKEY can be found in the SAP API Business Hub.

See [these additional options](https://github.com/Azure-Samples/app-service-javascript-sap-cloud-sdk-quickstart?tab=readme-ov-file#prerequisites--installation) for free and easy sandboxing with SAP APIs.

Find more information about on adding OData APIs in Azure API Management [here](https://learn.microsoft.com/azure/api-management/sap-api?tabs=odata).

### 1. Initialize a new `azd` environment

```shell
azd init -t azure-samples/azd-apic-sap
```

If you already cloned this repository to your local machine or run from a Dev Container or GitHub Codespaces you can run the following command from the root folder.

```shell
azd init
```

It will prompt you to provide a name that will later be used in the name of the deployed resources. If you're not logged into Azure, it will also prompt you to first login.

```shell
azd auth login
```

### 2. Provision and deploy all the resources

```shell
azd up
```

It will prompt you to login, pick a subscription, and provide a location (like "eastus"). We've added extra conditional parameters to optionally deploy: ...

For more details on the deployed services, see [additional details](#additional-details) below.

The conditional parameters set in the `azd up` command are stored in the .azure\<name>\config.json file:

```json
{
  "infra": {
    "parameters": {
      "deployAzureAPIMtoAPIC": "<true or false>", // Deploy Azure API Management APIs to API Center
      "deploySapAPIMtoAPIC": "<true or false>", // Deploy SAP API Management APIs to API Center
      // SAP API Management
      "sapApimTokenUrl": "<https://<your-sap-btp-service-instance-name>.authentication.<btp-region>.hana.ondemand.com/oauth/token>", // url property from SAP BTP service key
      "sapApimDiscoveryUrl": "<https://<btp-region>devportal.cfapps.<btp-region>.hana.ondemand.com/apidiscovery/v1/apis>", // The SAP API Management discovery URL
      "sapApimClientId": "<client id from SAP BTP service key>", // SAP API Management, developer portal
      "sapApimSecret": "<client secret from SAP BTP service key>", // SAP API Management, developer portal
      // Azure API Management specific for included automatic onboarding of OData API into Azure APIM
      "sapBackendEndpoint": "<SAP OData endpoint for Azure API Management>", // The SAP OData endpoint for Azure API Management
      "sapBackendApiKey": "<API key for Azure API Management solution>" // The SAP OData api key for API Azure Management
    }
  }
}
```

> [!NOTE]  
> Deploy only SAP API Management APIs to Azure API Center skipping Azure API Management APIs, by setting the `deployAzureAPIMtoAPIC` parameter to `false`. All input related to Azure API Management will be ignored. Same applies for the `deploySapAPIMtoAPIC` parameter for the SAP API Management APIs.

## Testing 🧪

- Use the test file [tests-sap-backend.http](tests-sap-backend.http) to check your Azure API Management deployment consuming from SAP Backend.

- Testing the SAP API Management Discovery can be done using the file [sap-apim-scan.http](sap-apim-scan.http).

- Check the environment variables in the `.env` file, or run the command below in the terminal. Keep in mind that secrets are not stored in the `.env` file, so you need to provide them manually.

```shell
azd env get-values
```

## What's next?

You can do a lot more once the app is deployed. Curious? We got you covered with some more information on the setup, monitoring, and DevOps [here](docs/ADDITIONAL_INFO.md).

## Contributing 👩🏼‍🤝‍👨🏽

This project welcomes contributions and suggestions. Please use [GitHub Issues](https://github.com/Azure-Samples/azd-apic-sap/issues/new/choose) to report errors or request new features.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks™

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
