*** Settings ***
Documentation       Tests related to the version of MicroShift

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

    ${configmap}=  Oc Get  configmap  kube-public  microshift-version
    Should Be Equal As Integers    ${configmap.data.major}    4
    Should Be Equal As Integers    ${configmap.data.minor}    14

CLI Output
    [Documentation]  Check the version reported by the process

    ${version}=  MicroShift Version
    Should Be Equal As Integers    ${version.major}    4
    Should Be Equal As Integers    ${version.minor}    14
    Should Start With  ${version.gitVersion}  4.14


ConfigMap Matches CLI
    [Documentation]  Ensure the ConfigMap is being updated based on the actual binary version

    ${configmap}=  Oc Get  configmap  kube-public  microshift-version
    ${cli}=  MicroShift Version
    Should Be Equal  ${configmap.data.version}  ${cli.gitVersion}
