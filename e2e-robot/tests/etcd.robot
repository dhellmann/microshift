*** Settings ***
Documentation       Tests related to how etcd is managed

Resource            ../resources/common.resource
Resource            ../resources/systemd.resource
Resource            ../resources/microshift-process.resource
Library             ../resources/YAML.py
Library             Collections

Suite Setup         Setup
Suite Teardown      Teardown


*** Variables ***
${USHIFT_IP}        ${EMPTY}
${USHIFT_USER}      ${EMPTY}
${ETCD_SYSTEMD_UNIT}	microshift-etcd.scope
${MEMLIMIT128}      SEPARATOR=\n
...  ---
...  etcd:
...  \ \ memoryLimitMB: 128
${MEMLIMIT128J}
...  {"etcd": {"memoryLimitMB": 128}}

*** Test Cases ***
# Show
#     Log  ${MEMLIMIT128}
#     Log  ${MEMLIMIT128J}
#     ${val}=  Convert to Yaml  ${MEMLIMIT128J}
#     Log  ${val}

Default MemoryHigh Unlimited
    [Documentation]  The default configuration should not limit RAM
    [Tags]  etcd  configuration  default
    Expect MemoryHigh  infinity

Set MemoryHigh Limit 128MB
    [Documentation]  Set the memory limit for etcd to 128MB and ensure it takes effect
    [Tags]  etcd  configuration
    Upload MicroShift Config  ${MEMLIMIT128}
    Restart MicroShift
    # Expecting the setting to be 128 * 1024 * 1024
    Expect MemoryHigh  134217728

*** Keywords ***
Setup
    Reset Default Config

Teardown
    Reset Default Config

Reset Default Config
    Clear MicroShift Config
    Restart MicroShift

Expect MemoryHigh
    [Arguments]  ${expected}
    ${actual}=  Get Systemd Setting  microshift-etcd.scope  MemoryHigh
    IF  ('${expected}' == 'infinity') or ('${actual}' == 'infinity')
        Should Be Equal  ${expected}  ${actual}
    ELSE
        Should Be Equal As Integers  ${expected}  ${actual}
    END
