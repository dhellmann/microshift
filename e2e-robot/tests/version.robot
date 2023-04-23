*** Settings ***
Documentation       MicroShift e2e test suite

Resource            ../resources/common.resource
Resource            ../resources/oc.resource
Resource            ../resources/microshift-process.resource
Library             ../resources/YAML.py
Library             Collections

Suite Setup         Get Kubeconfig
Suite Teardown      Remove Kubeconfig


*** Variables ***
${USHIFT_IP}        ${EMPTY}
${USHIFT_USER}      ${EMPTY}


*** Test Cases ***
ConfigMap Contents
    [Documentation]  Check the version of the server

    ${version_configmap}=  Oc Get  configmap  kube-public  microshift-version
    ${major_version}=  Yaml Get  ${version_configmap}  data.major
    Should Be Equal As Integers    ${major_version}    4
    ${minor_version}=  Yaml Get  ${version_configmap}  data.minor
    Should Be Equal As Integers    ${minor_version}    14

CLI Output
    [Documentation]  Check the version reported by the process

    ${version_data}=  MicroShift Version
    ${microshift_version}=  Get From Dictionary  ${version_data}  microshift
    Should Start With  ${microshift_version}  4.14


ConfigMap Matches CLI
    [Documentation]  Ensure the ConfigMap is being updated based on the actual binary version

    ${version_configmap}=  Oc Get  configmap  kube-public  microshift-version
    ${value_configmap}=  Yaml Get  ${version_configmap}  data.version
    ${version_cli}=  MicroShift Version
    ${value_cli}=  Get From Dictionary  ${version_cli}  microshift
    Should Be Equal  ${value_configmap}  ${value_cli}
