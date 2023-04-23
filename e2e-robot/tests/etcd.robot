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
Show
    Log  ${MEMLIMIT128}
    Log  ${MEMLIMIT128J}
    ${val}=  Convert to Yaml  ${MEMLIMIT128J}
    Log  ${val}

Default MemoryHigh Unlimited
    ${memory_high}=  Get Systemd Setting  microshift-etcd  MemoryHigh
    Should Be Equal  infinity  ${memory_high}

Set MemoryHigh Limit 128MB
    [Documentation]  Set the memory limit for etcd to 128MB and ensure it takes effect
    Upload MicroShift Config  ${MEMLIMIT128}
    Restart MicroShift
    ${memory_high}=  Get Systemd Setting  ${ETCD_SYSTEMD_UNIT}  MemoryHigh
    # Expecting the setting to be 128 * 1024 * 1024
    Should Be Equal As Integers  134217728  ${memory_high}

*** Keywords ***
Setup
    Reset Default Config

Teardown
    Reset Default Config

Reset Default Config
    Clear MicroShift Config
    Restart MicroShift
